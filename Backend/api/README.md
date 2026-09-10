# Retino-AI: Backend / API / Integration Layer

> **Smart India Hackathon (SIH) Project**  
> **Subsystem**: Part 2 — Backend API, Integration, Application & AI Service Adapter  
> **Location**: Strictly contained within `Backend/api/`

---

## 1. System Architecture & Role

The API layer acts as the central communication bridge connecting the **React Frontend** with the **Retinal AI Engine** and persistent **SQLite Database**:

```
[REACT FRONTEND]
       │
       ▼  (Multipart / JSON Requests)
[FASTAPI BACKEND]  ◄── (Backend/api/)
       │
       ▼  (Image + Clinical Request)
[AI ENGINE ADAPTER (ai_service.py)]
       │
       ▼  (Bridge Interface)
[AI ANALYSIS ENGINE]  ◄── (Backend/ai-engine/)
       │
       ▼  (Standardized JSON Result)
[FASTAPI BACKEND]  ──►  Persists in SQLite (retino_ai.db)
       │
       ▼  (Standardized JSON & Structured Reports)
[REACT FRONTEND]
```

---

## 2. Directory Structure

All files are strictly isolated within `Backend/api/`:

```
Backend/api/
├── README.md                      # Complete subsystem documentation (this file)
├── requirements.txt               # Backend Python dependencies
├── run.py                         # FastAPI server runner script (port 8000)
├── run_tests.py                   # Automated test runner script
├── retino_ai.db                   # SQLite database (auto-created on startup)
├── .gitignore                     # Git ignore rules for DB, caches, and test artifacts
├── app/
│   ├── __init__.py                # Package initializer
│   ├── main.py                    # FastAPI application, CORS, static uploads, routers
│   ├── config.py                  # Settings (DB path, uploads, CORS origins, AI provider)
│   ├── database.py                # SQLAlchemy engine, session generator, SQLite pragmas
│   ├── models/                    # Database ORM models
│   │   ├── __init__.py
│   │   ├── patient.py             # Patient model (demographics, ID)
│   │   ├── screening.py           # Screening model (session state, image path, timestamp)
│   │   ├── screening_result.py    # Standardized AI diagnostic result
│   │   └── doctor_verification.py # Doctor verification, overrides & clinical notes
│   ├── schemas/                   # Pydantic validation schemas
│   │   ├── __init__.py
│   │   ├── ai_result.py           # Standardized AI result contract
│   │   ├── patient.py             # Patient input & response schemas
│   │   ├── screening.py           # Screening session & complete report schemas
│   │   ├── doctor_verification.py # Doctor verification schemas
│   │   └── dashboard.py           # Dashboard statistics schemas
│   ├── services/                  # Business logic & AI Engine integration
│   │   ├── __init__.py
│   │   └── ai_service.py          # AIEngineInterface, MockAIService, RealAIEngineAdapter
│   ├── utils/                     # Supporting utilities
│   │   ├── __init__.py
│   │   ├── file_handler.py        # Safe image storage, size/type validation
│   │   └── exceptions.py          # Domain exceptions & standardized JSON errors
│   └── routers/                   # API endpoint controllers
│       ├── __init__.py
│       ├── health.py              # GET /api/health
│       ├── screenings.py          # POST /api/screenings, analyze, verify, details, list
│       └── dashboard.py           # GET /api/dashboard/stats
├── tests/
│   ├── __init__.py
│   └── test_api.py                # Pytest test suite covering all endpoints
└── uploads/                       # Storage for uploaded retinal fundus images
    └── .gitkeep
```

---

## 3. Standardized AI Integration Contract

The integration contract between the API and the AI engine conforms strictly to the following specification:

```json
{
  "severity": "Moderate",
  "confidence": 0.91,
  "referable": true,
  "image_quality": "Good",
  "findings": [
    "Microaneurysms detected in macular region",
    "Dot and blot hemorrhages in 2 quadrants",
    "Hard exudates present"
  ],
  "evidence_image": null,
  "severity_level": 2
}
```

### Severity Mapping & Referral Rules:
| Level | Severity Name | Referable Status |
| :---: | :--- | :---: |
| **0** | `No DR` | `false` |
| **1** | `Mild` | `false` |
| **2** | `Moderate` | `true` |
| **3** | `Severe` | `true` |
| **4** | `Proliferative DR` | `true` |

*Rule: Any case with severity level $\ge 2$ is classified as `referable: true`.*

---

## 4. API Endpoints Reference

### 4.1 Health Check
- **`GET /api/health`**
  - Response:
    ```json
    {
      "status": "ok",
      "service": "Retino-AI Backend API",
      "ai_engine_provider": "mock"
    }
    ```

### 4.2 Image Upload & Screening Creation
- **`POST /api/screenings`**
  - Content-Type: `multipart/form-data`
  - Parameters:
    - `name` (string, required): Patient's full name
    - `age` (integer, required): Patient's age (0–150)
    - `gender` (string, required): e.g. "Male", "Female", "Other"
    - `patient_id` (string, optional): Unique ID. Auto-generated if omitted.
    - `file` (file, required): Fundus image (`.png`, `.jpg`, `.jpeg`, max 15MB)
  - Response (`201 Created`):
    ```json
    {
      "screening_id": 1,
      "patient_id": "P001",
      "status": "created"
    }
    ```

### 4.3 AI Analysis
- **`POST /api/screenings/{id}/analyze`**
  - Triggers AI analysis on the uploaded fundus image.
  - Returns the standardized AI result and persists it to SQLite.
  - Response (`200 OK`):
    ```json
    {
      "severity": "Moderate",
      "confidence": 0.91,
      "referable": true,
      "image_quality": "Good",
      "findings": [
        "Microaneurysms detected in macular region",
        "Dot and blot hemorrhages in 2 quadrants"
      ],
      "evidence_image": null,
      "severity_level": 2
    }
    ```

### 4.4 Doctor Verification
- **`POST /api/screenings/{id}/verify`**
  - Allows an ophthalmologist to confirm or override the AI diagnosis.
  - Body:
    ```json
    {
      "decision": "confirmed",
      "final_severity": "Moderate",
      "notes": "Requires ophthalmologist referral within 2-4 weeks"
    }
    ```
  - Response (`200 OK`):
    ```json
    {
      "screening_id": 1,
      "decision": "confirmed",
      "final_severity": "Moderate",
      "notes": "Requires ophthalmologist referral within 2-4 weeks",
      "verification_timestamp": "2026-09-09T13:36:09.440221"
    }
    ```

### 4.5 Complete Screening & Report Data
- **`GET /api/screenings/{id}`**
  - Returns the complete data bundle for React report generation and review screens.
  - Response (`200 OK`):
    ```json
    {
      "screening_id": 1,
      "patient_id": "P001",
      "patient": {
        "patient_id": "P001",
        "name": "Aarav Patel",
        "age": 54,
        "gender": "Male",
        "created_at": "2026-09-09T13:36:09.418182"
      },
      "image_url": "http://127.0.0.1:8000/uploads/fundus_a448a705478c.png",
      "image_path": "fundus_a448a705478c.png",
      "status": "verified",
      "timestamp": "2026-09-09T13:36:09.418182",
      "image_quality": "Good",
      "severity": "Moderate",
      "severity_level": 2,
      "confidence": 0.91,
      "referable": true,
      "findings": [
        "Microaneurysms detected in macular region",
        "Dot and blot hemorrhages in 2 quadrants"
      ],
      "evidence_image": null,
      "doctor_decision": "confirmed",
      "final_severity": "Moderate",
      "doctor_notes": "Requires ophthalmologist referral within 2-4 weeks",
      "verification_timestamp": "2026-09-09T13:36:09.440221",
      "report_data": {
        "report_id": "REP-SCR-0001",
        "generated_at": "2026-09-09T13:36:09.444982",
        "patient": { "id": "P001", "name": "Aarav Patel", "age": 54, "gender": "Male" },
        "diagnosis": {
          "ai_severity": "Moderate",
          "final_severity": "Moderate",
          "referable": true,
          "confidence": 0.91,
          "doctor_decision": "confirmed",
          "doctor_notes": "Requires ophthalmologist referral within 2-4 weeks"
        },
        "clinical_findings": [ ... ],
        "recommendation": "Immediate specialist ophthalmology referral required."
      }
    }
    ```

### 4.6 Screening List
- **`GET /api/screenings`**
  - Query parameters:
    - `limit` (int, default: 50)
    - `offset` (int, default: 0)
    - `status` (string, optional): e.g. "created", "analyzed", "verified"
    - `referable` (bool, optional): true / false
  - Returns array of `ScreeningSummary` objects.

### 4.7 Dashboard Analytics
- **`GET /api/dashboard/stats`**
  - Aggregated metrics for the React dashboard widgets and charts:
    ```json
    {
      "total_screenings": 24,
      "total_patients": 20,
      "referable_cases": 9,
      "non_referable_cases": 15,
      "referable_percentage": 37.5,
      "pending_doctor_reviews": 3,
      "verified_screenings": 21,
      "severity_distribution": {
        "No DR": 10,
        "Mild": 5,
        "Moderate": 6,
        "Severe": 2,
        "Proliferative DR": 1
      },
      "image_quality_distribution": {
        "Good": 20,
        "Adequate": 3,
        "Poor": 1
      }
    }
    ```

---

## 5. How to Run the Server

From the repository root or from `Backend/api/`:

```bash
# Using the dedicated runner script:
python3 Backend/api/run.py
```

Or using `uvicorn` directly:

```bash
uvicorn --app-dir Backend/api app.main:app --host 0.0.0.0 --port 8000 --reload
```

Once running:
- **Interactive Swagger UI**: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- **Alternative ReDoc UI**: [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc)
- **Health Check**: [http://127.0.0.1:8000/api/health](http://127.0.0.1:8000/api/health)

---

## 6. How to Run the Tests

Execute the automated test suite with either command:

```bash
# Option 1: Standalone runner
python3 Backend/api/run_tests.py

# Option 2: Using pytest directly
python3 -m pytest Backend/api/tests/ -v
```

All tests execute against an isolated in-memory SQLite database and test client.

---

## 7. MATLAB AI Engine Integration Guide

The real AI Engine is MATLAB-based and located under `Backend/ai-engine/`:
- **Inference Entry Point**: `Backend/ai-engine/matlab/inference/predict_dr.m`
- **Trained Model Artifact**: `Backend/ai-engine/models/saved/dr_random_forest.mat` (100 Decision Trees, 12 mask-free features, 5 classes)
- **Model Metadata**: `Backend/ai-engine/models/saved/dr_model_metadata.json`

### Bridge Architecture in `RealAIEngineAdapter`:
[`Backend/api/app/services/ai_service.py`](file:///Users/rithwickgn/Retino-AI/Backend/api/app/services/ai_service.py) implements the Python ↔ MATLAB bridge:
1. Resolves absolute paths to `predict_dr.m`, `setup_paths.m`, and `dr_random_forest.mat`.
2. Validates image existence on disk.
3. Checks for **MATLAB Engine API for Python** (`import matlab.engine`).
4. If unavailable, falls back to **MATLAB CLI batch mode** (`matlab -batch "..."`).
5. Extracts and normalizes the MATLAB struct output into the `StandardAIResult` schema:
   - Severity grades $0 \to \text{"No DR"}$, $1 \to \text{"Mild"}$, $2 \to \text{"Moderate"}$, $3 \to \text{"Severe"}$, $4 \to \text{"Proliferative DR"}$.
   - Referable computed as $\text{grade} \ge 2$.
6. To activate real inference:
   ```bash
   export AI_ENGINE_PROVIDER=real
   python3 Backend/api/run.py
   ```
   *Note: If neither `matlab.engine` nor the `matlab` CLI is installed on the host machine, the adapter raises an explicit `AIAnalysisError` indicating the environment dependency blocker.*
