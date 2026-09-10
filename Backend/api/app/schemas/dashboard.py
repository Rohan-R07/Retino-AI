from typing import Dict, List, Optional
from pydantic import BaseModel, Field


class DashboardStatsResponse(BaseModel):
    """Aggregated statistics for the React dashboard."""
    total_screenings: int = Field(..., description="Total number of screenings recorded")
    total_patients: int = Field(..., description="Total unique patients registered")
    referable_cases: int = Field(..., description="Screenings with referable diabetic retinopathy (Moderate, Severe, Proliferative)")
    non_referable_cases: int = Field(..., description="Screenings with No DR or Mild non-referable DR")
    referable_percentage: float = Field(..., description="Percentage of analyzed cases that are referable")
    pending_doctor_reviews: int = Field(..., description="Analyzed screenings awaiting doctor verification")
    verified_screenings: int = Field(..., description="Screenings verified by a physician/ophthalmologist")
    severity_distribution: Dict[str, int] = Field(
        ...,
        description="Count of screenings per DR severity grade",
        examples=[{"No DR": 5, "Mild": 2, "Moderate": 3, "Severe": 1, "Proliferative DR": 1}],
    )
    image_quality_distribution: Dict[str, int] = Field(
        ...,
        description="Count of screenings per image quality grade",
        examples=[{"Good": 10, "Adequate": 2, "Poor": 0}],
    )
