"""
AI Engine Integration Layer for Retino-AI.

This module defines:
1. The abstract interface (AIEngineInterface) defining the contract between FastAPI and the AI engine.
2. The standardized JSON result contract (StandardAIResult).
3. A clearly-marked MockAIService for development and isolated API unit testing.
4. The RealAIEngineAdapter connecting FastAPI to the teammate's MATLAB AI Engine (predict_dr.m).
"""

import os
import sys
import json
import logging
import hashlib
import shutil
import tempfile
import subprocess
import ast
import types
import importlib.util
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Dict, List, Optional, Any

from app.config import AI_ENGINE_PROVIDER, BASE_DIR
from app.schemas.ai_result import StandardAIResult
from app.utils.exceptions import AIAnalysisError

logger = logging.getLogger("retino_ai.ai_service")

# Standardized Clinical Severity Mapping (0 to 4)
SEVERITY_LEVEL_MAP: Dict[str, int] = {
    "No DR": 0,
    "Mild": 1,
    "Moderate": 2,
    "Severe": 3,
    "Proliferative DR": 4,
}

LEVEL_TO_SEVERITY_MAP: Dict[int, str] = {v: k for k, v in SEVERITY_LEVEL_MAP.items()}


class AIEngineInterface(ABC):
    """
    Abstract Base Interface for Retinal AI Engine.
    All implementations (mock, real MATLAB adapter, external service) MUST fulfill this interface.
    """

    @abstractmethod
    async def analyze(self, image_path: str) -> StandardAIResult:
        """
        Analyze a retinal fundus image and return the standardized AI result.

        Args:
            image_path: Absolute or relative filesystem path to the fundus image.

        Returns:
            StandardAIResult: Validated Pydantic model matching the standard contract.
        """
        pass


class MockAIService(AIEngineInterface):
    """
    ===========================================================================
    [MOCK IMPLEMENTATION FOR DEVELOPMENT & TEST ENVIRONMENT ONLY]
    ===========================================================================
    This mock service produces clinically coherent test predictions adhering
    strictly to the Retino-AI standardized integration contract.
    It is active ONLY when AI_ENGINE_PROVIDER=mock (or during unit tests).
    """

    SCENARIOS = [
        {
            "severity": "Moderate",
            "severity_level": 2,
            "confidence": 0.91,
            "referable": True,
            "image_quality": "Good",
            "findings": [
                "Microaneurysms detected in macular region",
                "Dot and blot hemorrhages in 2 quadrants",
                "Hard exudates present",
            ],
            "evidence_image": None,
        },
        {
            "severity": "No DR",
            "severity_level": 0,
            "confidence": 0.97,
            "referable": False,
            "image_quality": "Good",
            "findings": ["Normal retinal vasculature", "Clear optic disc margin", "Foveal reflex intact"],
            "evidence_image": None,
        },
        {
            "severity": "Mild",
            "severity_level": 1,
            "confidence": 0.88,
            "referable": False,
            "image_quality": "Good",
            "findings": ["Isolated microaneurysms in temporal arcade"],
            "evidence_image": None,
        },
        {
            "severity": "Severe",
            "severity_level": 3,
            "confidence": 0.94,
            "referable": True,
            "image_quality": "Adequate",
            "findings": [
                "Severe intraretinal hemorrhages in all 4 quadrants",
                "Venous beading in 2 quadrants",
                "Cotton wool spots present",
            ],
            "evidence_image": None,
        },
        {
            "severity": "Proliferative DR",
            "severity_level": 4,
            "confidence": 0.96,
            "referable": True,
            "image_quality": "Good",
            "findings": [
                "Neovascularization of the disc (NVD)",
                "Pre-retinal fibrous proliferation",
                "Vitreous hemorrhage risk",
            ],
            "evidence_image": None,
        },
    ]

    async def analyze(self, image_path: str) -> StandardAIResult:
        logger.info("[MockAIService] Analyzing image: %s", image_path)

        if not os.path.exists(image_path):
            raise AIAnalysisError(f"Image file does not exist on disk: {image_path}")

        file_hash = hashlib.md5(Path(image_path).name.encode()).hexdigest()
        scenario_idx = int(file_hash, 16) % len(self.SCENARIOS)
        data = self.SCENARIOS[scenario_idx].copy()
        data["referable"] = data["severity_level"] >= 2

        logger.info(
            "[MockAIService] Result: severity=%s, level=%d, confidence=%.2f, referable=%s",
            data["severity"],
            data["severity_level"],
            data["confidence"],
            data["referable"],
        )

        return StandardAIResult(**data)


class RealAIEngineAdapter(AIEngineInterface):
    """
    ===========================================================================
    [REAL AI ENGINE ADAPTER]
    ===========================================================================
    Direct bridge to the teammate's AI pipeline located in `Backend/ai-engine/`.
    Connects FastAPI to the trained 100-tree Random Forest classifier artifact
    (dr_random_forest.mat) and feature extraction pipeline.

    Execution Strategy:
    1. Native Python AI Engine: Directly imports and executes the validated
       Python inference implementation from Backend/ai-engine/ without needing MATLAB.
    2. MATLAB Engine API for Python (`import matlab.engine`) if available.
    3. System `matlab` command-line batch execution if available.
    4. If none can execute, raises a descriptive AIAnalysisError.
    """

    def __init__(self):
        # Resolve absolute directories robustly
        self.root_dir = BASE_DIR.parent
        self.ai_engine_dir = self.root_dir / "ai-engine"
        self.matlab_dir = self.ai_engine_dir / "matlab"
        self.config_dir = self.ai_engine_dir / "config"
        self.inference_dir = self.matlab_dir / "inference"
        self.predict_dr_script = self.inference_dir / "predict_dr.m"
        self.python_inference_script = self.ai_engine_dir / "tests" / "validate_model_inference.py"
        self.python_qa_script = self.ai_engine_dir / "tests" / "validate_quality_assessment.py"

        # Locate trained Random Forest model artifact
        candidate_model_paths = [
            self.ai_engine_dir / "models" / "saved" / "dr_random_forest.mat",
            self.matlab_dir / "models" / "saved" / "dr_random_forest.mat",
        ]
        self.model_path: Optional[Path] = None
        for p in candidate_model_paths:
            if p.is_file():
                self.model_path = p
                break

        self._python_engine: Optional[Dict[str, Any]] = None
        self.matlab_cli_path = self._find_matlab_cli()
        self.has_matlab_engine = self._probe_matlab_engine()

        logger.info(
            "[RealAIEngineAdapter] Initialized. AI Engine: %s | Python Inference: %s | Model: %s | "
            "Engine API: %s | CLI: %s",
            self.ai_engine_dir,
            self.python_inference_script.is_file(),
            self.model_path is not None,
            self.has_matlab_engine,
            self.matlab_cli_path,
        )

    def _load_python_engine(self) -> Dict[str, Any]:
        """
        Dynamically load the teammate's existing Python inference engine
        from Backend/ai-engine/tests/validate_model_inference.py.
        Filters out the held-out test harness at the bottom of the script
        so it functions purely as an inference module.
        """
        if self._python_engine is not None:
            return self._python_engine

        if not self.python_inference_script.is_file():
            raise AIAnalysisError(
                f"AI Engine Python inference script not found at: {self.python_inference_script}"
            )

        if not self.model_path or not self.model_path.is_file():
            raise AIAnalysisError(
                f"Trained Random Forest artifact dr_random_forest.mat not found in: {self.ai_engine_dir}/models/saved/"
            )

        try:
            with open(self.python_inference_script, "r", encoding="utf-8") as f:
                source = f.read()

            tree = ast.parse(source)
            # Filter statements to include all setup, extract_12_features, and predict_dr,
            # cutting off before the held-out test harness at the bottom of the file
            filtered_body = []
            for node in tree.body:
                if isinstance(node, ast.Assign):
                    targets = [getattr(t, "id", None) for t in node.targets]
                    if "held_out_file" in targets:
                        break
                filtered_body.append(node)
            tree.body = filtered_body

            mod = types.ModuleType("retino_ai_inference")
            mod.__file__ = str(self.python_inference_script)
            exec(compile(tree, filename=str(self.python_inference_script), mode="exec"), mod.__dict__)

            # Also load QA module if available
            qa_mod = None
            if self.python_qa_script.is_file():
                try:
                    spec = importlib.util.spec_from_file_location("retino_ai_qa", str(self.python_qa_script))
                    if spec and spec.loader:
                        qa_mod = importlib.util.module_from_spec(spec)
                        spec.loader.exec_module(qa_mod)
                except Exception as qa_exc:
                    logger.warning("[RealAIEngineAdapter] QA helper note: %s", qa_exc)

            self._python_engine = {
                "module": mod,
                "model": getattr(mod, "model", None),
                "predict_dr": getattr(mod, "predict_dr", None),
                "qa_module": qa_mod,
            }
            logger.info("[RealAIEngineAdapter] Successfully loaded native Python AI Engine with 100-tree model.")
            return self._python_engine
        except Exception as exc:
            logger.error("[RealAIEngineAdapter] Failed to load Python AI Engine: %s", exc)
            raise AIAnalysisError(f"Failed to initialize Python AI Engine: {exc}") from exc

    async def _run_via_python_engine(self, image_path: str, model_path: str) -> StandardAIResult:
        """
        Run real inference using the teammate's existing Python AI Engine.
        """
        engine = self._load_python_engine()
        predict_fn = engine["predict_dr"]
        model = engine["model"]
        qa_mod = engine.get("qa_module")

        if predict_fn is None or model is None:
            raise AIAnalysisError("Python AI Engine predict_dr function or model structure is not loaded.")

        # 1. Quality Assessment Gatekeeper audit
        image_quality = "Good"
        quality_rejections = []
        if qa_mod and hasattr(qa_mod, "assess_image_quality_py"):
            try:
                pil_image_mod = importlib.import_module("PIL.Image")
                np_mod = importlib.import_module("numpy")

                with pil_image_mod.open(image_path) as pil_im:
                    img_arr = np_mod.array(pil_im.convert("RGB"))
                q_res = qa_mod.assess_image_quality_py(img_arr)
                if q_res.get("is_gradable", True):
                    image_quality = "Good" if q_res.get("overall_quality") == "excellent" else "Adequate"
                else:
                    image_quality = "Poor"
                    quality_rejections = q_res.get("rejection_reasons", [])
            except Exception as q_err:
                logger.warning("[RealAIEngineAdapter] Quality check exception: %s", q_err)

        # 2. Execute 12-feature extraction and 100-tree Random Forest inference
        try:
            res = predict_fn(str(image_path), model)
        except Exception as exc:
            logger.error("[RealAIEngineAdapter] AI Engine predict_dr execution error: %s", exc)
            raise AIAnalysisError(f"AI Engine inference execution error: {exc}") from exc

        status_str = str(res.get("status", "GRADABLE")).upper()
        is_gradable = bool(res.get("is_gradable", False)) and (status_str == "GRADABLE")
        advisory = res.get("advisory", "")
        raw_grade = res.get("predicted_grade")

        # 3. Handle ungradable / poor quality image rejection
        if not is_gradable or raw_grade is None or (isinstance(raw_grade, float) and str(raw_grade).lower() == "nan"):
            findings = []
            if advisory:
                findings.append(f"Quality Advisory: {advisory}")
            if quality_rejections:
                findings.extend(quality_rejections)
            if not findings:
                findings.append("Image ungradable due to insufficient illumination, focus blur, or aperture clipping.")

            return StandardAIResult(
                severity="No DR",
                severity_level=0,
                confidence=0.0,
                referable=False,
                image_quality="Poor",
                findings=findings,
                evidence_image=None,
            )

        # 4. Map gradable prediction
        predicted_grade = int(round(float(raw_grade)))
        severity = LEVEL_TO_SEVERITY_MAP.get(predicted_grade, "Moderate")
        confidence = float(res.get("confidence", 0.0))
        referable = bool(predicted_grade >= 2)

        # 5. Assemble clinical findings based on actual AI engine outputs
        findings = []
        if advisory:
            findings.append(advisory)

        clinical_descriptions = {
            0: "No clinically significant microaneurysms, hemorrhages, or lipid exudates detected within the retinal field of view.",
            1: "Isolated microaneurysms or mild intraretinal microvascular alterations detected. Early stage NPDR; 6-month monitoring recommended.",
            2: "Multiple microaneurysms, dot/blot hemorrhages, or hard exudates identified. Moderate NPDR threshold reached. Specialist referral recommended.",
            3: "Severe intraretinal hemorrhages or vascular abnormalities observed across quadrants. Urgent retinal specialist referral required.",
            4: "Evidence of proliferative diabetic retinopathy (PDR) or severe neovascularization detected. Immediate tertiary clinical intervention required.",
        }
        if predicted_grade in clinical_descriptions:
            findings.append(clinical_descriptions[predicted_grade])

        feat_vec = res.get("feature_vector")
        feat_names = res.get("feature_names", [])
        if feat_vec and feat_names and len(feat_vec) >= 12:
            findings.append(
                f"Biomarker vector: 12 mask-free features analyzed (GLCM contrast: {feat_vec[8]:.2f}, "
                f"GLCM correlation: {feat_vec[9]:.3f}, green channel mean: {feat_vec[6]:.1f})."
            )

        return StandardAIResult(
            severity=severity,
            severity_level=predicted_grade,
            confidence=round(confidence, 4),
            referable=referable,
            image_quality=image_quality,
            findings=findings,
            evidence_image=res.get("evidence_image", None),
        )

    def _probe_matlab_engine(self) -> bool:
        """Check if matlab.engine Python package is importable."""
        try:
            import importlib
            importlib.import_module("matlab.engine")
            return True
        except (ImportError, ModuleNotFoundError):
            return False

    def _find_matlab_cli(self) -> Optional[str]:
        """Check for matlab binary in PATH or standard OS installation locations."""
        cli = shutil.which("matlab")
        if cli:
            return cli

        # Standard macOS installation paths
        mac_candidates = [
            Path("/Applications/MATLAB_R2024b.app/bin/matlab"),
            Path("/Applications/MATLAB_R2024a.app/bin/matlab"),
            Path("/Applications/MATLAB_R2023b.app/bin/matlab"),
            Path("/Applications/MATLAB_R2023a.app/bin/matlab"),
            Path("/Applications/MATLAB_R2022b.app/bin/matlab"),
            Path("/usr/local/bin/matlab"),
            Path("/opt/matlab/bin/matlab"),
        ]
        for c in mac_candidates:
            if c.is_file() and os.access(c, os.X_OK):
                return str(c)

        return None

    async def analyze(self, image_path: str) -> StandardAIResult:
        """
        Execute real AI inference through existing Python AI Engine or MATLAB fallback.
        """
        image_file = Path(image_path).resolve()
        if not image_file.is_file():
            raise AIAnalysisError(f"Fundus retinal image not found on disk: {image_file}")

        if not self.model_path or not self.model_path.is_file():
            raise AIAnalysisError(
                f"Trained Random Forest artifact dr_random_forest.mat not found in: {self.ai_engine_dir}/models/saved/"
            )

        # 1. Primary Strategy: Native Python AI Engine (No MATLAB required)
        if self.python_inference_script.is_file():
            logger.info("[RealAIEngineAdapter] Executing inference via native Python AI Engine...")
            return await self._run_via_python_engine(str(image_file), str(self.model_path))

        # 2. Fallback: Attempt MATLAB Engine API for Python
        if self.has_matlab_engine:
            logger.info("[RealAIEngineAdapter] Executing inference via MATLAB Engine API...")
            return await self._run_via_engine(str(image_file), str(self.model_path))

        # 3. Fallback: Attempt MATLAB CLI Batch Execution
        if self.matlab_cli_path:
            logger.info("[RealAIEngineAdapter] Executing inference via MATLAB CLI: %s...", self.matlab_cli_path)
            return await self._run_via_cli(str(image_file), str(self.model_path))

        # 4. Environment/Dependency Blocker
        err_msg = (
            "AI Engine Inference Blocker: Could not locate the Python inference entry point "
            f"('{self.python_inference_script}') nor a functional MATLAB installation."
        )
        logger.error("[RealAIEngineAdapter] %s", err_msg)
        raise AIAnalysisError(err_msg)

    async def _run_via_engine(self, image_path: str, model_path: str) -> StandardAIResult:
        """Run predict_dr.m via MATLAB Engine API for Python."""
        try:
            import importlib
            matlab_engine = importlib.import_module("matlab.engine")

            eng = matlab_engine.start_matlab()
            try:
                # Add all required MATLAB paths
                eng.addpath(eng.genpath(str(self.matlab_dir)), nargout=0)
                eng.addpath(str(self.config_dir), nargout=0)

                # Call predict_dr
                raw_struct = eng.predict_dr(str(image_path), str(model_path), nargout=1)
                return self._parse_matlab_struct(raw_struct)
            finally:
                eng.quit()
        except Exception as exc:
            logger.error("[RealAIEngineAdapter] MATLAB Engine call failed: %s", exc)
            raise AIAnalysisError(f"MATLAB Engine execution error in predict_dr.m: {exc}")

    async def _run_via_cli(self, image_path: str, model_path: str) -> StandardAIResult:
        """Run predict_dr.m via MATLAB CLI batch execution."""
        temp_dir = Path(tempfile.gettempdir())
        output_json_path = temp_dir / f"retino_ai_out_{hashlib.md5(image_path.encode()).hexdigest()[:8]}.json"

        # MATLAB batch command
        matlab_cmd = (
            f"try, "
            f"addpath(genpath('{self.matlab_dir}')); "
            f"addpath('{self.config_dir}'); "
            f"res = predict_dr('{image_path}', '{model_path}'); "
            f"fid = fopen('{output_json_path}', 'w'); "
            f"fwrite(fid, jsonencode(res)); "
            f"fclose(fid); "
            f"catch ME, "
            f"fid = fopen('{output_json_path}', 'w'); "
            f"errStruct = struct('status', 'ERROR', 'advisory', ME.message); "
            f"fwrite(fid, jsonencode(errStruct)); "
            f"fclose(fid); "
            f"end; "
            f"exit;"
        )

        cmd = [self.matlab_cli_path, "-batch", matlab_cmd]
        logger.info("[RealAIEngineAdapter] Running CLI command: %s", " ".join(cmd))

        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=120,
            )
            if proc.returncode != 0:
                raise AIAnalysisError(
                    f"MATLAB process exited with code {proc.returncode}. Stderr: {proc.stderr.strip()}"
                )

            if not output_json_path.exists():
                raise AIAnalysisError(
                    f"MATLAB finished but output JSON was not generated at {output_json_path}. Output: {proc.stdout}"
                )

            with open(output_json_path, "r") as f:
                data = json.load(f)

            if data.get("status") == "ERROR":
                raise AIAnalysisError(f"MATLAB predict_dr error: {data.get('advisory', 'Unknown error')}")

            return self._parse_matlab_struct(data)
        except subprocess.TimeoutExpired:
            raise AIAnalysisError("MATLAB execution timed out after 120 seconds.")
        except Exception as exc:
            if isinstance(exc, AIAnalysisError):
                raise
            raise AIAnalysisError(f"Error invoking MATLAB CLI: {exc}")
        finally:
            if output_json_path.exists():
                try:
                    output_json_path.unlink()
                except Exception:
                    pass

    def _parse_matlab_struct(self, raw: Any) -> StandardAIResult:
        """
        Map real MATLAB predict_dr result struct into StandardAIResult contract.
        """
        # Convert MATLAB struct to standard Python dict if needed
        if hasattr(raw, "keys") and callable(raw.keys):
            d = dict(raw)
        elif isinstance(raw, dict):
            d = raw
        else:
            d = {}

        status_str = str(d.get("status", "GRADABLE")).upper()
        raw_grade = d.get("predicted_grade")
        advisory = d.get("advisory", "")

        # Handle ungradable / poor quality image gatekeeper
        if status_str == "UNGRADABLE" or raw_grade is None or str(raw_grade).lower() == "nan":
            return StandardAIResult(
                severity="No DR",
                severity_level=0,
                confidence=0.0,
                referable=False,
                image_quality="Poor",
                findings=[f"Quality Advisory: {advisory}"] if advisory else ["Image ungradable"],
                evidence_image=None,
            )

        predicted_grade = int(round(float(raw_grade)))
        severity = LEVEL_TO_SEVERITY_MAP.get(predicted_grade, "Moderate")
        confidence = float(d.get("confidence", 0.0))
        # Ensure referral rule: Level >= 2 -> True
        referable = bool(predicted_grade >= 2)

        # Quality assessment
        quality_info = d.get("quality", {})
        if isinstance(quality_info, dict) and quality_info.get("is_gradable", True):
            image_quality = "Good"
        else:
            image_quality = "Good" if status_str == "GRADABLE" else "Poor"

        # Findings
        findings: List[str] = []
        if advisory:
            findings.append(advisory)

        # Feature vector summary if provided
        feat_vector = d.get("feature_vector")
        feat_names = d.get("feature_names", [])
        if feat_vector and feat_names and len(feat_vector) == len(feat_names):
            findings.append(f"Analyzed {len(feat_vector)} mask-free color and GLCM texture features.")

        return StandardAIResult(
            severity=severity,
            severity_level=predicted_grade,
            confidence=round(confidence, 4),
            referable=referable,
            image_quality=image_quality,
            findings=findings,
            evidence_image=d.get("evidence_image", None),
        )


# Global instances
_mock_instance = MockAIService()
_real_instance: Optional[RealAIEngineAdapter] = None


def get_ai_service() -> AIEngineInterface:
    """
    Factory function providing the configured AI service implementation.
    Controlled by environment variable AI_ENGINE_PROVIDER:
        'mock' (default) -> MockAIService
        'real'           -> RealAIEngineAdapter
    """
    global _real_instance
    provider = os.getenv("AI_ENGINE_PROVIDER", AI_ENGINE_PROVIDER).lower()
    if provider == "real":
        if _real_instance is None:
            _real_instance = RealAIEngineAdapter()
        return _real_instance
    return _mock_instance
