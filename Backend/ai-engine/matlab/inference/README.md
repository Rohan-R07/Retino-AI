# Module: Inference (`matlab/inference/`)

**Phase Planned:** Phase 8  
**Subsystem:** Retino-AI End-to-End Single-Image Inference Pipeline

---

## Purpose & Scope
This module ties together the entire processing pipeline into a unified, modular interface. It receives a single fundus image file path, coordinates quality checks, preprocessing, feature extraction, classification, and explainability generation, and returns a structured diagnostic report.

## Planned Capabilities (Future Development)
* **Unified Pipeline Orchestration:**
  1. Image reading & dimension validation.
  2. Quality assessment gatekeeping (proceed only if image is gradable).
  3. Preprocessing (masking, green channel extraction, CLAHE).
  4. Feature extraction (vessels, lesions, optic disc).
  5. Classifier inference (predicting DR grade 0–4 and confidence scores).
  6. Explainability artifact rendering (overlay image with lesion markers).
* **Conceptual Signature:**
  ```matlab
  result = analyze_fundus(imagePath, modelPath, config);
  ```
* **Output Structure (Conceptual Design):**
  * `result.is_gradable` (boolean)
  * `result.quality_metrics` (struct)
  * `result.dr_grade` (integer: 0–4)
  * `result.dr_label` (string: e.g., "Moderate NPDR")
  * `result.confidence` (double: e.g., 0.88)
  * `result.referral_recommended` (boolean)
  * `result.detected_lesions` (struct with counts/coordinates)
  * `result.explanation_image_path` (string)

## Planned Interfaces (Future Placeholder)
* `analyze_fundus.m`: Future master inference entry point.
