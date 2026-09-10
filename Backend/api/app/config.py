import os
from pathlib import Path
from typing import List

# Base directory for the API layer: Backend/api
BASE_DIR = Path(__file__).resolve().parent.parent

# Database configuration (SQLite Prototype stored strictly in Backend/api/)
DATABASE_FILE = os.getenv("DATABASE_FILE", str(BASE_DIR / "retino_ai.db"))
DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{DATABASE_FILE}")

# Upload directory for fundus retinal images
UPLOAD_DIR = Path(os.getenv("UPLOAD_DIR", str(BASE_DIR / "uploads")))
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

# Image upload restrictions
MAX_IMAGE_SIZE_BYTES = int(os.getenv("MAX_IMAGE_SIZE_BYTES", str(15 * 1024 * 1024)))  # 15 MB
ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".JPG", ".JPEG", ".PNG"}
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png"}

# CORS settings for React (Vite/CRA) frontend
DEFAULT_CORS_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:5173",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:5173",
]
CORS_ORIGINS_ENV = os.getenv("CORS_ORIGINS", "")
if CORS_ORIGINS_ENV:
    CORS_ORIGINS: List[str] = [origin.strip() for origin in CORS_ORIGINS_ENV.split(",") if origin.strip()]
else:
    CORS_ORIGINS = DEFAULT_CORS_ORIGINS

# AI Engine configuration
# Options: "mock" (default clinical mock for API dev/testing) or "real" (bridges to Backend/ai-engine/)
AI_ENGINE_PROVIDER = os.getenv("AI_ENGINE_PROVIDER", "mock").lower()
