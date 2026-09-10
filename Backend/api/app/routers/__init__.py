from app.routers.health import router as health_router
from app.routers.screenings import router as screenings_router
from app.routers.dashboard import router as dashboard_router

__all__ = ["health_router", "screenings_router", "dashboard_router"]
