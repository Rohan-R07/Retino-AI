from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class PatientBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=255, description="Full name of the patient", examples=["John Doe"])
    age: int = Field(..., ge=0, le=150, description="Age in years", examples=[58])
    gender: str = Field(..., description="Gender (e.g. Male, Female, Other)", examples=["Male"])


class PatientCreate(PatientBase):
    patient_id: Optional[str] = Field(
        default=None,
        description="Optional external patient identifier. If omitted, will be auto-generated.",
        examples=["P001"],
    )


class PatientResponse(PatientBase):
    patient_id: str = Field(..., description="Unique patient identifier", examples=["P001"])
    created_at: datetime = Field(..., description="Registration timestamp")

    model_config = {"from_attributes": True}
