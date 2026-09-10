from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class DoctorVerificationCreate(BaseModel):
    decision: str = Field(
        ...,
        description="Doctor's verification decision: 'confirmed', 'modified', or 'rejected'",
        examples=["confirmed"],
    )
    final_severity: str = Field(
        ...,
        description="Final validated Diabetic Retinopathy severity (e.g. 'No DR', 'Mild', 'Moderate', 'Severe', 'Proliferative DR')",
        examples=["Moderate"],
    )
    notes: Optional[str] = Field(
        default=None,
        description="Clinical notes and recommendations by the verifying ophthalmologist/physician",
        examples=["Requires ophthalmologist referral within 2-4 weeks."],
    )


class DoctorVerificationResponse(BaseModel):
    screening_id: int = Field(..., description="Screening ID")
    decision: str = Field(..., description="Doctor decision ('confirmed', 'modified', 'rejected')")
    final_severity: str = Field(..., description="Final verified DR severity")
    notes: Optional[str] = Field(None, description="Doctor notes")
    verification_timestamp: datetime = Field(..., description="Timestamp of verification")

    model_config = {"from_attributes": True}
