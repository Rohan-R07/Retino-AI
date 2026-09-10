from datetime import datetime
from typing import List, Optional, Any, Dict
from pydantic import BaseModel, Field
from app.schemas.patient import PatientResponse
from app.schemas.ai_result import StandardAIResult
from app.schemas.doctor_verification import DoctorVerificationResponse


class ScreeningCreateResponse(BaseModel):
    """Response returned upon POST /api/screenings creation."""
    screening_id: int = Field(..., description="Generated screening ID", examples=[1])
    patient_id: str = Field(..., description="Patient ID", examples=["P001"])
    status: str = Field(..., description="Screening status", examples=["created"])


class ScreeningSummary(BaseModel):
    """Summary representation for screening lists."""
    screening_id: int
    patient_id: str
    patient_name: Optional[str] = None
    patient_age: Optional[int] = None
    patient_gender: Optional[str] = None
    image_url: str
    status: str
    timestamp: datetime
    # AI Result fields (if analyzed)
    severity: Optional[str] = None
    severity_level: Optional[int] = None
    confidence: Optional[float] = None
    referable: Optional[bool] = None
    image_quality: Optional[str] = None
    # Doctor verification flag
    is_verified: bool = False
    verified_severity: Optional[str] = None

    model_config = {"from_attributes": True}


class CompleteScreeningResponse(BaseModel):
    """
    Complete screening information returned by GET /api/screenings/{id}.
    Provides all data needed for React report and detail screens.
    """
    screening_id: int
    patient_id: str
    patient: Optional[PatientResponse] = None
    image_url: str
    image_path: str
    status: str
    timestamp: datetime

    # AI Analysis details
    image_quality: Optional[str] = None
    severity: Optional[str] = None
    severity_level: Optional[int] = None
    confidence: Optional[float] = None
    referable: Optional[bool] = None
    findings: List[str] = Field(default_factory=list)
    evidence_image: Optional[str] = None

    # Doctor Verification details
    doctor_verification: Optional[DoctorVerificationResponse] = None
    doctor_decision: Optional[str] = None
    final_severity: Optional[str] = None
    doctor_notes: Optional[str] = None
    verification_timestamp: Optional[datetime] = None

    # Complete structured report data for React frontend
    report_data: Optional[Dict[str, Any]] = None

    model_config = {"from_attributes": True}
