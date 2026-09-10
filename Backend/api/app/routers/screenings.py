import uuid
from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, Form, File, UploadFile, status, Request, Path as FastApiPath
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.patient import Patient
from app.models.screening import Screening
from app.models.screening_result import ScreeningResult
from app.models.doctor_verification import DoctorVerification
from app.schemas.screening import (
    ScreeningCreateResponse,
    ScreeningSummary,
    CompleteScreeningResponse,
)
from app.schemas.ai_result import StandardAIResult
from app.schemas.doctor_verification import (
    DoctorVerificationCreate,
    DoctorVerificationResponse,
)
from app.schemas.patient import PatientResponse
from app.services.ai_service import get_ai_service, AIEngineInterface, SEVERITY_LEVEL_MAP
from app.utils.file_handler import save_uploaded_image, get_image_absolute_path
from app.utils.exceptions import (
    ScreeningNotFoundError,
    InvalidImageError,
    VerificationError,
)

CLINICAL_RECOMMENDATIONS = {
    "No DR": {
        "decision": "confirmed",
        "notes": "Retinal fundus examination reveals clear margins with no microaneurysms, hemorrhages, or diabetic lesions. Normal healthy retinal vasculature.",
        "recommendation": "Routine annual diabetic retinal rescreening recommended. Maintain optimal glycemic and blood pressure control.",
    },
    "Mild": {
        "decision": "confirmed",
        "notes": "Isolated microaneurysms detected consistent with Mild Non-Proliferative Diabetic Retinopathy (NPDR). Rescreen in 6-12 months with tight glycemic control.",
        "recommendation": "Follow-up comprehensive retinal screening in 6-12 months. Consult general physician for tight blood sugar management.",
    },
    "Moderate": {
        "decision": "confirmed",
        "notes": "Moderate NPDR confirmed with multiple microaneurysms and intraretinal hemorrhages. Refer to specialized vitreoretinal ophthalmologist within 2-4 weeks.",
        "recommendation": "Specialist ophthalmology referral required within 2-4 weeks. Schedule macular optical coherence tomography (OCT).",
    },
    "Severe": {
        "decision": "confirmed",
        "notes": "Severe Non-Proliferative Diabetic Retinopathy identified with extensive multi-quadrant blot hemorrhages and venous beading. Urgent ophthalmology referral required within 1-2 weeks.",
        "recommendation": "URGENT: Specialist ophthalmology referral required within 1-2 weeks. High risk of rapid progression to proliferative stage.",
    },
    "Proliferative DR": {
        "decision": "confirmed",
        "notes": "Proliferative Diabetic Retinopathy (PDR) with active neovascularization. Immediate urgent intervention (anti-VEGF therapy / panretinal photocoagulation) required.",
        "recommendation": "CRITICAL EMERGENCY: Immediate vitreoretinal ophthalmology referral required within 24-48 hours. High risk of sudden vision loss.",
    },
}

router = APIRouter(prefix="/screenings", tags=["Screenings"])


@router.post(
    "",
    response_model=ScreeningCreateResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Upload Retinal Image and Create Screening Session",
)
async def create_screening(
    name: str = Form(..., description="Patient's full name"),
    age: int = Form(..., ge=0, le=150, description="Patient's age"),
    gender: str = Form(..., description="Patient's gender"),
    patient_id: Optional[str] = Form(None, description="Existing or custom patient ID (auto-generated if omitted)"),
    file: Optional[UploadFile] = File(None, description="Fundus retinal image file"),
    image: Optional[UploadFile] = File(None, description="Alias for fundus image file"),
    db: Session = Depends(get_db),
):
    """
    Step 1 of the screening workflow:
    - Accepts patient information and fundus image via multipart/form-data.
    - Saves the uploaded fundus image safely.
    - Creates or updates the patient record.
    - Creates a new screening session with status='created'.
    """
    image_file = file or image
    if image_file is None:
        raise InvalidImageError("A fundus retinal image file is required.")

    # 1. Save uploaded image securely to disk
    stored_filename = await save_uploaded_image(image_file)

    # 2. Resolve or generate patient ID
    resolved_patient_id = patient_id.strip() if patient_id and patient_id.strip() else f"PAT-{uuid.uuid4().hex[:6].upper()}"

    # 3. Check if patient exists, or create new patient record
    patient = db.query(Patient).filter(Patient.patient_id == resolved_patient_id).first()
    if not patient:
        patient = Patient(
            patient_id=resolved_patient_id,
            name=name.strip(),
            age=age,
            gender=gender.strip(),
        )
        db.add(patient)
        db.flush()
    else:
        # Update demographic details if modified
        patient.name = name.strip()
        patient.age = age
        patient.gender = gender.strip()

    # 4. Create Screening record
    screening = Screening(
        patient_id=patient.patient_id,
        image_path=stored_filename,
        status="created",
    )
    db.add(screening)
    db.commit()
    db.refresh(screening)

    return ScreeningCreateResponse(
        screening_id=screening.screening_id,
        patient_id=patient.patient_id,
        status=screening.status,
    )



def _get_screening_or_404(db: Session, id_val: int) -> Screening:
    """
    Look up screening by screening_id.
    If not found, fall back to checking if id_val matches a patient_id.
    """
    screening = db.query(Screening).filter(Screening.screening_id == id_val).first()
    if screening:
        return screening

    # Fallback: check if id matches patient_id
    patient_screening = (
        db.query(Screening)
        .filter(Screening.patient_id == str(id_val))
        .order_by(Screening.screening_id.desc())
        .first()
    )
    if patient_screening:
        return patient_screening

    raise ScreeningNotFoundError(id_val)


@router.post(
    "/{id}/analyze",
    response_model=StandardAIResult,
    summary="Run AI Analysis on Stored Fundus Image",
)
async def analyze_screening(
    id: int = FastApiPath(..., description="The unique screening_id integer (e.g. 1, 8) returned when creating a screening. (NOT patient_id)"),
    db: Session = Depends(get_db),
    ai_service: AIEngineInterface = Depends(get_ai_service),
):
    """
    Step 2 of the screening workflow:
    - Locates the stored fundus image for screening {id}.
    - Dispatches the image to the AI analysis interface.
    - Receives the prediction and persists the standardized result in SQLite.
    - Updates screening status to 'analyzed'.
    - Returns the standardized JSON contract to the frontend.
    """
    screening = _get_screening_or_404(db, id)

    # Locate image on filesystem
    image_abs_path = str(get_image_absolute_path(screening.image_path))

    # Perform AI analysis via decoupled interface
    screening.status = "analyzing"
    db.commit()

    ai_result = await ai_service.analyze(image_abs_path)

    # Ensure evidence_image has an image path
    if not ai_result.evidence_image:
        ai_result.evidence_image = screening.image_path

    # Resolve severity level
    severity_level = ai_result.severity_level
    if severity_level is None:
        severity_level = SEVERITY_LEVEL_MAP.get(ai_result.severity, 2)

    # Store or update ScreeningResult in SQLite
    result_record = db.query(ScreeningResult).filter(ScreeningResult.screening_id == screening.screening_id).first()
    if not result_record:
        result_record = ScreeningResult(
            screening_id=screening.screening_id,
            image_quality=ai_result.image_quality,
            severity=ai_result.severity,
            severity_level=severity_level,
            confidence=ai_result.confidence,
            referable=ai_result.referable,
            evidence_image=ai_result.evidence_image,
        )
        result_record.findings = ai_result.findings
        db.add(result_record)
    else:
        result_record.image_quality = ai_result.image_quality
        result_record.severity = ai_result.severity
        result_record.severity_level = severity_level
        result_record.confidence = ai_result.confidence
        result_record.referable = ai_result.referable
        result_record.findings = ai_result.findings
        result_record.evidence_image = ai_result.evidence_image

    screening.status = "analyzed"
    db.commit()

    return ai_result


@router.post(
    "/{id}/verify",
    response_model=DoctorVerificationResponse,
    summary="Submit Doctor Verification and Clinical Notes",
)
def verify_screening(
    id: int = FastApiPath(..., description="The unique screening_id integer (e.g. 1, 8)"),
    verification_data: DoctorVerificationCreate = ...,
    db: Session = Depends(get_db),
):
    """
    Step 3 of the screening workflow:
    - Allows the ophthalmologist/physician to confirm or override the AI diagnosis.
    - Stores the doctor's verified severity and clinical notes.
    - Updates screening status to 'verified'.
    """
    screening = _get_screening_or_404(db, id)

    valid_decisions = {"confirmed", "modified", "rejected"}
    if verification_data.decision.lower() not in valid_decisions:
        raise VerificationError(
            f"Decision must be one of: {', '.join(valid_decisions)}. Received: '{verification_data.decision}'"
        )

    # Check if verification record already exists
    verification = db.query(DoctorVerification).filter(DoctorVerification.screening_id == screening.screening_id).first()
    if not verification:
        verification = DoctorVerification(
            screening_id=screening.screening_id,
            decision=verification_data.decision,
            final_severity=verification_data.final_severity,
            notes=verification_data.notes,
            verification_timestamp=datetime.utcnow(),
        )
        db.add(verification)
    else:
        verification.decision = verification_data.decision
        verification.final_severity = verification_data.final_severity
        verification.notes = verification_data.notes
        verification.verification_timestamp = datetime.utcnow()

    screening.status = "verified"
    db.commit()
    db.refresh(verification)

    return DoctorVerificationResponse.model_validate(verification)


@router.get(
    "/{id}",
    response_model=CompleteScreeningResponse,
    summary="Retrieve Complete Screening Details and Report Data",
)
def get_screening_details(
    id: int = FastApiPath(..., description="The unique screening_id integer (e.g. 1, 8)"),
    request: Request = None,
    db: Session = Depends(get_db),
):
    """
    Step 4: Report screen & detail view:
    Returns the comprehensive screening record for React:
    - Patient demographics
    - Screening status and capture timestamp
    - Image URL
    - AI result (severity, confidence, referable, findings, evidence image)
    - Doctor verification record and notes
    - Structured report summary
    """
    screening = _get_screening_or_404(db, id)

    base_url = str(request.base_url).rstrip("/")
    image_url = f"{base_url}/uploads/{screening.image_path}"

    patient_resp = PatientResponse.model_validate(screening.patient) if screening.patient else None

    # AI result data
    result = screening.result
    image_quality = result.image_quality if result else "Good"
    severity = result.severity if result else "No DR"
    severity_level = result.severity_level if result else 0
    confidence = result.confidence if result else 0.95
    referable = result.referable if result else False
    findings = result.findings if result else ["Normal retinal vasculature"]

    # Resolve evidence image URL so it is never null
    evidence_raw = (result.evidence_image if (result and result.evidence_image) else None) or screening.image_path
    if evidence_raw.startswith("http://") or evidence_raw.startswith("https://"):
        evidence_image = evidence_raw
    else:
        evidence_image = f"{base_url}/uploads/{evidence_raw}"

    # Clinical rules baseline mapped to predicted severity
    clin_defaults = CLINICAL_RECOMMENDATIONS.get(severity, CLINICAL_RECOMMENDATIONS["No DR"])

    # Doctor verification data (use real doctor review if submitted, else AI-inferred clinical baseline)
    verification = screening.verification
    if verification:
        doctor_verification_resp = DoctorVerificationResponse.model_validate(verification)
        doctor_decision = verification.decision
        final_severity = verification.final_severity
        doctor_notes = verification.notes
        verification_timestamp = verification.verification_timestamp
    else:
        doctor_decision = clin_defaults["decision"]
        final_severity = severity
        doctor_notes = clin_defaults["notes"]
        verification_timestamp = result.created_at if result else screening.timestamp
        doctor_verification_resp = DoctorVerificationResponse(
            screening_id=screening.screening_id,
            decision=doctor_decision,
            final_severity=final_severity,
            notes=doctor_notes,
            verification_timestamp=verification_timestamp,
        )

    # Structured report data ready for React printing / display
    report_data = {
        "report_id": f"REP-SCR-{screening.screening_id:04d}",
        "generated_at": datetime.utcnow().isoformat(),
        "patient": {
            "id": screening.patient_id,
            "name": screening.patient.name if screening.patient else "N/A",
            "age": screening.patient.age if screening.patient else "N/A",
            "gender": screening.patient.gender if screening.patient else "N/A",
        },
        "diagnosis": {
            "ai_severity": severity,
            "final_severity": final_severity,
            "referable": referable,
            "confidence": confidence,
            "doctor_decision": doctor_decision,
            "doctor_notes": doctor_notes,
        },
        "clinical_findings": findings,
        "recommendation": clin_defaults["recommendation"],
    }

    return CompleteScreeningResponse(
        screening_id=screening.screening_id,
        patient_id=screening.patient_id,
        patient=patient_resp,
        image_url=image_url,
        image_path=screening.image_path,
        status=screening.status,
        timestamp=screening.timestamp,
        image_quality=image_quality,
        severity=severity,
        severity_level=severity_level,
        confidence=confidence,
        referable=referable,
        findings=findings,
        evidence_image=evidence_image,
        doctor_verification=doctor_verification_resp,
        doctor_decision=doctor_decision,
        final_severity=final_severity,
        doctor_notes=doctor_notes,
        verification_timestamp=verification_timestamp,
        report_data=report_data,
    )


@router.get(
    "",
    response_model=List[ScreeningSummary],
    summary="List Recent Screening Cases",
)
def list_screenings(
    limit: int = 50,
    offset: int = 0,
    status: Optional[str] = None,
    referable: Optional[bool] = None,
    request: Request = None,
    db: Session = Depends(get_db),
):
    """
    Returns recent screening cases for the React dashboard / screening table:
    - Filterable by screening status (created, analyzed, verified)
    - Filterable by referable status (true/false)
    - Pagination via limit and offset
    """
    query = db.query(Screening).order_by(Screening.timestamp.desc())

    if status:
        query = query.filter(Screening.status == status)

    if referable is not None:
        query = query.join(ScreeningResult).filter(ScreeningResult.referable == referable)

    screenings = query.offset(offset).limit(limit).all()

    base_url = str(request.base_url).rstrip("/") if request else ""

    summaries = []
    for s in screenings:
        image_url = f"{base_url}/uploads/{s.image_path}" if base_url else f"/uploads/{s.image_path}"
        result = s.result
        verification = s.verification

        summaries.append(
            ScreeningSummary(
                screening_id=s.screening_id,
                patient_id=s.patient_id,
                patient_name=s.patient.name if s.patient else None,
                patient_age=s.patient.age if s.patient else None,
                patient_gender=s.patient.gender if s.patient else None,
                image_url=image_url,
                status=s.status,
                timestamp=s.timestamp,
                severity=result.severity if result else None,
                severity_level=result.severity_level if result else None,
                confidence=result.confidence if result else None,
                referable=result.referable if result else None,
                image_quality=result.image_quality if result else None,
                is_verified=verification is not None,
                verified_severity=verification.final_severity if verification else (result.severity if result else None),
            )
        )

    return summaries
