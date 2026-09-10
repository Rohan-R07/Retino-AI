from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.database import get_db
from app.models.patient import Patient
from app.models.screening import Screening
from app.models.screening_result import ScreeningResult
from app.models.doctor_verification import DoctorVerification
from app.schemas.dashboard import DashboardStatsResponse

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/stats", response_model=DashboardStatsResponse, summary="Get Dashboard Analytics Statistics")
def get_dashboard_stats(db: Session = Depends(get_db)):
    """
    Returns aggregated metrics and distributions for the React dashboard:
    - Total screenings and patients
    - Referable vs non-referable cases
    - Severity distribution
    - Pending vs verified doctor reviews
    - Image quality assessment distribution
    """
    total_screenings = db.query(func.count(Screening.screening_id)).scalar() or 0
    total_patients = db.query(func.count(Patient.patient_id)).scalar() or 0

    referable_cases = (
        db.query(func.count(ScreeningResult.id))
        .filter(ScreeningResult.referable == True)  # noqa: E712
        .scalar()
        or 0
    )
    non_referable_cases = (
        db.query(func.count(ScreeningResult.id))
        .filter(ScreeningResult.referable == False)  # noqa: E712
        .scalar()
        or 0
    )

    total_analyzed = referable_cases + non_referable_cases
    referable_percentage = round((referable_cases / total_analyzed * 100.0), 1) if total_analyzed > 0 else 0.0

    # Verified count
    verified_screenings = db.query(func.count(DoctorVerification.id)).scalar() or 0

    # Pending review: analyzed but not yet verified
    pending_doctor_reviews = (
        db.query(func.count(Screening.screening_id))
        .filter(Screening.status == "analyzed")
        .scalar()
        or 0
    )

    # Severity distribution
    severity_counts = (
        db.query(ScreeningResult.severity, func.count(ScreeningResult.id))
        .group_by(ScreeningResult.severity)
        .all()
    )
    severity_distribution = {
        "No DR": 0,
        "Mild": 0,
        "Moderate": 0,
        "Severe": 0,
        "Proliferative DR": 0,
    }
    for severity_name, count in severity_counts:
        severity_distribution[severity_name] = count

    # Image quality distribution
    quality_counts = (
        db.query(ScreeningResult.image_quality, func.count(ScreeningResult.id))
        .group_by(ScreeningResult.image_quality)
        .all()
    )
    image_quality_distribution = {"Good": 0, "Adequate": 0, "Poor": 0}
    for quality_name, count in quality_counts:
        image_quality_distribution[quality_name] = count

    return DashboardStatsResponse(
        total_screenings=total_screenings,
        total_patients=total_patients,
        referable_cases=referable_cases,
        non_referable_cases=non_referable_cases,
        referable_percentage=referable_percentage,
        pending_doctor_reviews=pending_doctor_reviews,
        verified_screenings=verified_screenings,
        severity_distribution=severity_distribution,
        image_quality_distribution=image_quality_distribution,
    )
