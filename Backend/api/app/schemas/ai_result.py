from typing import List, Optional
from pydantic import BaseModel, Field


class StandardAIResult(BaseModel):
    """
    Standardized AI integration result contract.
    This contract matches the agreed specification between FastAPI and the AI engine.
    """
    severity: str = Field(
        ...,
        description="Diabetic Retinopathy severity classification: 'No DR', 'Mild', 'Moderate', 'Severe', 'Proliferative DR'",
        examples=["Moderate"],
    )
    confidence: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Model confidence score between 0.0 and 1.0",
        examples=[0.91],
    )
    referable: bool = Field(
        ...,
        description="True if severity is Level 2 (Moderate) or above, requiring specialist referral",
        examples=[True],
    )
    image_quality: str = Field(
        ...,
        description="Fundus image quality assessment ('Good', 'Adequate', 'Poor')",
        examples=["Good"],
    )
    findings: List[str] = Field(
        default_factory=list,
        description="List of clinical findings detected (e.g. microaneurysms, hemorrhages, hard exudates)",
        examples=[["Microaneurysms in macula", "Hard exudates"]],
    )
    evidence_image: Optional[str] = Field(
        default=None,
        description="Path or URL to the explainability heatmap / evidence image if generated",
        examples=[None],
    )
    severity_level: Optional[int] = Field(
        default=None,
        ge=0,
        le=4,
        description="Internal numerical severity level: 0 (No DR) to 4 (Proliferative DR)",
        examples=[2],
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "severity": "Moderate",
                "confidence": 0.91,
                "referable": True,
                "image_quality": "Good",
                "findings": [],
                "evidence_image": None,
                "severity_level": 2,
            }
        }
    }
