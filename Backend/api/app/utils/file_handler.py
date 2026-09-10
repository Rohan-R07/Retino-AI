import uuid
from pathlib import Path
from fastapi import UploadFile
from app.config import (
    UPLOAD_DIR,
    ALLOWED_IMAGE_EXTENSIONS,
    ALLOWED_MIME_TYPES,
    MAX_IMAGE_SIZE_BYTES,
)
from app.utils.exceptions import (
    InvalidImageError,
    UnsupportedImageFormatError,
    ImageTooLargeError,
)


async def save_uploaded_image(image_file: UploadFile) -> str:
    """
    Validate and safely persist an uploaded fundus image to disk.

    Returns:
        str: Stored relative image filename (e.g. 'fundus_abc123.jpg')
    """
    if not image_file or not image_file.filename:
        raise InvalidImageError("No image file provided.")

    original_name = Path(image_file.filename).name
    ext = Path(original_name).suffix.lower()

    if ext not in {e.lower() for e in ALLOWED_IMAGE_EXTENSIONS}:
        raise UnsupportedImageFormatError(ext, ALLOWED_IMAGE_EXTENSIONS)

    # Check content-type if provided
    if image_file.content_type and image_file.content_type.lower() not in ALLOWED_MIME_TYPES:
        # Some clients send octet-stream for valid images, so warn/allow if extension is valid,
        # but if mime is explicitly a non-image type (like text/plain, application/pdf), reject.
        if not image_file.content_type.startswith("image/"):
            raise InvalidImageError(f"File content type '{image_file.content_type}' is not a recognized image type.")

    # Read content and validate size
    content = await image_file.read()
    if len(content) == 0:
        raise InvalidImageError("Uploaded file is empty.")

    if len(content) > MAX_IMAGE_SIZE_BYTES:
        max_mb = MAX_IMAGE_SIZE_BYTES // (1024 * 1024)
        raise ImageTooLargeError(max_mb)

    # Generate secure, unique filename to prevent path traversal and collision
    safe_filename = f"fundus_{uuid.uuid4().hex[:12]}{ext}"
    destination = UPLOAD_DIR / safe_filename

    with open(destination, "wb") as f:
        f.write(content)

    return safe_filename


def get_image_absolute_path(filename: str) -> Path:
    """Get absolute path to a saved image."""
    return UPLOAD_DIR / filename
