import os
import sys
import io
import pytest
from pathlib import Path
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

# Ensure Backend/api is on sys.path
api_dir = Path(__file__).resolve().parent.parent
if str(api_dir) not in sys.path:
    sys.path.insert(0, str(api_dir))

from app.main import app
from app.database import Base, get_db
from app.services.ai_service import get_ai_service, MockAIService

# Setup an isolated in-memory SQLite database for testing
TEST_DATABASE_URL = "sqlite:///:memory:"
test_engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


def override_get_ai_service():
    return MockAIService()


# Apply dependency overrides
app.dependency_overrides[get_db] = override_get_db
app.dependency_overrides[get_ai_service] = override_get_ai_service

# Minimal 1x1 transparent PNG bytes for testing image uploads
TINY_PNG_BYTES = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\rIDATx\x9cc`\x00\x00\x00"
    b"\x02\x00\x01H\xaf\xa4q\x00\x00\x00\x00IEND\xaeB`\x82"
)


@pytest.fixture(scope="module", autouse=True)
def setup_test_db():
    """Create database tables before tests and tear down after."""
    Base.metadata.create_all(bind=test_engine)
    yield
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture
def client():
    return TestClient(app)


def test_health_check(client):
    """Test GET /api/health endpoint."""
    response = client.get("/api/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "service" in data


def test_create_screening_success(client):
    """Test POST /api/screenings image upload and screening creation."""
    files = {
        "file": ("test_fundus.png", io.BytesIO(TINY_PNG_BYTES), "image/png"),
    }
    data = {
        "name": "Rohan Sharma",
        "age": 52,
        "gender": "Male",
        "patient_id": "P001",
    }
    response = client.post("/api/screenings", data=data, files=files)
    assert response.status_code == 201
    resp_data = response.json()
    assert resp_data["screening_id"] == 1
    assert resp_data["patient_id"] == "P001"
    assert resp_data["status"] == "created"


def test_create_screening_unsupported_format(client):
    """Test image upload with unsupported file format (.txt)."""
    files = {
        "file": ("notes.txt", io.BytesIO(b"Hello world text"), "text/plain"),
    }
    data = {
        "name": "Test Patient",
        "age": 40,
        "gender": "Female",
    }
    response = client.post("/api/screenings", data=data, files=files)
    assert response.status_code in [400, 415]


def test_create_screening_missing_image(client):
    """Test POST /api/screenings without an image file."""
    data = {
        "name": "Test Patient",
        "age": 40,
        "gender": "Female",
    }
    response = client.post("/api/screenings", data=data)
    assert response.status_code == 400


def test_analyze_screening_success(client):
    """Test POST /api/screenings/{id}/analyze runs AI engine and returns standardized JSON."""
    response = client.post("/api/screenings/1/analyze")
    assert response.status_code == 200
    ai_result = response.json()

    # Validate exact standardized contract fields
    assert "severity" in ai_result
    assert "confidence" in ai_result
    assert "referable" in ai_result
    assert "image_quality" in ai_result
    assert "findings" in ai_result
    assert "evidence_image" in ai_result

    # Validate types and clinical constraints
    assert ai_result["severity"] in ["No DR", "Mild", "Moderate", "Severe", "Proliferative DR"]
    assert isinstance(ai_result["confidence"], (int, float))
    assert 0.0 <= ai_result["confidence"] <= 1.0
    assert isinstance(ai_result["referable"], bool)
    assert isinstance(ai_result["findings"], list)


def test_analyze_screening_not_found(client):
    """Test POST /api/screenings/{id}/analyze with non-existent screening ID."""
    response = client.post("/api/screenings/9999/analyze")
    assert response.status_code == 404
    assert response.json()["error"] == "SCREENING_NOT_FOUND"


def test_verify_screening_success(client):
    """Test POST /api/screenings/{id}/verify doctor confirmation/override."""
    payload = {
        "decision": "confirmed",
        "final_severity": "Moderate",
        "notes": "Verified by Dr. Sharma. Refer to retina specialist within 3 weeks.",
    }
    response = client.post("/api/screenings/1/verify", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["screening_id"] == 1
    assert data["decision"] == "confirmed"
    assert data["final_severity"] == "Moderate"
    assert data["notes"] == payload["notes"]
    assert "verification_timestamp" in data


def test_verify_screening_invalid_decision(client):
    """Test POST /api/screenings/{id}/verify with an unrecognized decision."""
    payload = {
        "decision": "unsure_maybe",
        "final_severity": "Moderate",
    }
    response = client.post("/api/screenings/1/verify", json=payload)
    assert response.status_code == 400


def test_get_screening_details(client):
    """Test GET /api/screenings/{id} returns complete report info for React."""
    response = client.get("/api/screenings/1")
    assert response.status_code == 200
    data = response.json()
    assert data["screening_id"] == 1
    assert data["patient_id"] == "P001"
    assert data["patient"]["name"] == "Rohan Sharma"
    assert data["status"] == "verified"
    assert data["severity"] is not None
    assert data["confidence"] is not None
    assert data["final_severity"] == "Moderate"
    assert data["doctor_decision"] == "confirmed"
    assert "report_data" in data
    assert data["report_data"]["diagnosis"]["final_severity"] == "Moderate"


def test_list_screenings(client):
    """Test GET /api/screenings returns list of recent screenings."""
    response = client.get("/api/screenings")
    assert response.status_code == 200
    screenings = response.json()
    assert isinstance(screenings, list)
    assert len(screenings) >= 1
    assert screenings[0]["screening_id"] == 1
    assert screenings[0]["is_verified"] is True


def test_dashboard_stats(client):
    """Test GET /api/dashboard/stats returns aggregated metrics."""
    response = client.get("/api/dashboard/stats")
    assert response.status_code == 200
    stats = response.json()
    assert stats["total_screenings"] >= 1
    assert stats["total_patients"] >= 1
    assert "referable_cases" in stats
    assert "non_referable_cases" in stats
    assert "severity_distribution" in stats
    assert "image_quality_distribution" in stats
    assert isinstance(stats["severity_distribution"], dict)
