import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse

from app.config import CORS_ORIGINS, UPLOAD_DIR
from app.database import init_db
from app.routers import health_router, screenings_router, dashboard_router
from app.utils.exceptions import RetinoAPIException

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("retino_ai.main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup and shutdown lifespan events."""
    logger.info("Initializing Retino-AI API Database and Storage...")
    init_db()
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    logger.info("Retino-AI API startup complete. Ready for requests.")
    yield
    logger.info("Retino-AI API shutting down.")


# Create FastAPI application
app = FastAPI(
    title="Retino-AI Backend API",
    description="""
# Retino-AI: Retinal Screening & AI Analysis Integration API
Smart India Hackathon (SIH) Project

This backend API serves as the bridge between the **React Frontend** and the **Retinal AI Engine**.

### Workflow:
1. **Screening Creation (`POST /api/screenings`)**: Accepts patient metadata and retinal fundus image.
2. **AI Analysis (`POST /api/screenings/{id}/analyze`)**: Dispatches the fundus image to the AI engine and persists standardized diagnostic results.
3. **Doctor Verification (`POST /api/screenings/{id}/verify`)**: Allows clinical review, severity overrides, and doctor notes.
4. **Detail & Report Retrieval (`GET /api/screenings/{id}`)**: Returns comprehensive report data formatted for React.
5. **Dashboard Analytics (`GET /api/dashboard/stats`)**: Delivers statistics on screenings, severity distribution, and review backlog.
""",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configure CORS for React/Vite development
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve uploaded retinal images statically for React previews
if UPLOAD_DIR.exists():
    app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")


# Exception Handlers
@app.exception_handler(RetinoAPIException)
async def handle_retino_api_exception(request: Request, exc: RetinoAPIException):
    return JSONResponse(
        status_code=exc.status_code,
        content=exc.detail if isinstance(exc.detail, dict) else {"error": "API_ERROR", "message": str(exc.detail)},
    )


@app.exception_handler(Exception)
async def handle_generic_exception(request: Request, exc: Exception):
    logger.exception("Unhandled server exception: %s", exc)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"error": "INTERNAL_SERVER_ERROR", "message": "An unexpected server error occurred."},
    )


# Root welcome endpoint
@app.get("/", tags=["General"], summary="Root Endpoint")
def root():
    return {
        "project": "Retino-AI API Layer",
        "status": "online",
        "documentation": "/docs",
        "redoc": "/redoc",
        "health": "/api/health",
    }


# Include routers under /api prefix
app.include_router(health_router, prefix="/api")
app.include_router(screenings_router, prefix="/api")
app.include_router(dashboard_router, prefix="/api")
