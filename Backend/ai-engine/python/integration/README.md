# Python Integration Bridge (`python/integration/`)

## Purpose & Scope
This directory is reserved strictly for the future bridge between the MATLAB-based AI Engine and the teammate's FastAPI backend (Phase 9).

## Future Responsibilities
* **Communication Options:**
  * Option A: MATLAB Engine API for Python (`import matlab.engine`).
  * Option B: Command-line execution / compiled standalone executable invocation (`matlab -batch "analyze_fundus(...)"`).
  * Option C: File-based queue / JSON interface (writing inputs to a job folder, reading structured JSON outputs).
* **Contract Specification:**
  * Standardizing output JSON schema to match the teammate's backend database models and frontend visualizer requirements.
* **Note:** Do not implement FastAPI endpoints, models, or network code here. The teammate handles the web server and API contracts.
