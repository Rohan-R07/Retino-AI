import os
from pathlib import Path
from typing import List

# Base directory for the API layer: Backend/api
BASE_DIR = Path(__file__).resolve().parent.parent

# Automatically load environment variables from .env if present
def _load_env_file():
    try:
        from dotenv import load_dotenv
        for candidate in (BASE_DIR / ".env", BASE_DIR.parent.parent / ".env"):
            if candidate.is_file():
                load_dotenv(candidate, override=False)
        return
    except ImportError:
        pass

    # Built-in fallback loader if python-dotenv is not installed
    for candidate in (BASE_DIR / ".env", BASE_DIR.parent.parent / ".env"):
        if candidate.is_file():
            try:
                with open(candidate, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith("#") or "=" not in line:
                            continue
                        key, val = line.split("=", 1)
                        key = key.strip()
                        val = val.strip().strip("\"'")
                        if key and key not in os.environ:
                            os.environ[key] = val
            except Exception:
                pass

_load_env_file()

# Database configuration (SQLite Prototype stored strictly in Backend/api/)
_raw_db_file = os.getenv("DATABASE_FILE", str(BASE_DIR / "retino_ai.db"))
_db_path = Path(_raw_db_file)
if not _db_path.is_absolute():
    _db_path = BASE_DIR / _db_path
DATABASE_FILE = str(_db_path)

_raw_db_url = os.getenv("DATABASE_URL")
if not _raw_db_url or _raw_db_url in (f"sqlite:///{_raw_db_file}", "sqlite:///retino_ai.db"):
    DATABASE_URL = f"sqlite:///{DATABASE_FILE}"
else:
    DATABASE_URL = _raw_db_url

# Upload directory for fundus retinal images
_raw_upload_dir = os.getenv("UPLOAD_DIR", str(BASE_DIR / "uploads"))
_upload_path = Path(_raw_upload_dir)
if not _upload_path.is_absolute():
    _upload_path = BASE_DIR / _upload_path
UPLOAD_DIR = _upload_path
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
