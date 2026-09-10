from fastapi import APIRouter
from app.config import AI_ENGINE_PROVIDER

router = APIRouter(tags=["Health"])


@router.get("/health", summary="Service Health Check")
async def health_check():
    """
    Health check endpoint for Retino-AI backend.
    Returns operational status and active AI engine mode.
    """
    return {
        "status": "ok",
        "service": "Retino-AI Backend API",
        "ai_engine_provider": AI_ENGINE_PROVIDER,
    }
