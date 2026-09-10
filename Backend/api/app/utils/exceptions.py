from fastapi import HTTPException, status


class RetinoAPIException(HTTPException):
    """Base API exception class."""
    def __init__(self, status_code: int, detail: str, error_code: str = "API_ERROR"):
        super().__init__(status_code=status_code, detail={"error": error_code, "message": detail})


class PatientNotFoundError(RetinoAPIException):
    def __init__(self, patient_id: str):
        super().__init__(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Patient with ID '{patient_id}' not found.",
            error_code="PATIENT_NOT_FOUND",
        )


class ScreeningNotFoundError(RetinoAPIException):
    def __init__(self, screening_id: int):
        super().__init__(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Screening with ID {screening_id} not found.",
            error_code="SCREENING_NOT_FOUND",
        )


class InvalidImageError(RetinoAPIException):
    def __init__(self, detail: str = "Uploaded file is not a valid fundus image."):
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail,
            error_code="INVALID_IMAGE",
        )


class UnsupportedImageFormatError(RetinoAPIException):
    def __init__(self, extension: str, allowed: set):
        super().__init__(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported image format '{extension}'. Allowed formats: {', '.join(sorted(allowed))}",
            error_code="UNSUPPORTED_FORMAT",
        )


class ImageTooLargeError(RetinoAPIException):
    def __init__(self, max_mb: int):
        super().__init__(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Image file exceeds maximum allowable size of {max_mb} MB.",
            error_code="IMAGE_TOO_LARGE",
        )


class AIAnalysisError(RetinoAPIException):
    def __init__(self, detail: str = "AI analysis failed to process fundus image."):
        super().__init__(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=detail,
            error_code="AI_ANALYSIS_FAILED",
        )


class VerificationError(RetinoAPIException):
    def __init__(self, detail: str = "Invalid doctor verification payload."):
        super().__init__(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=detail,
            error_code="INVALID_VERIFICATION",
        )
