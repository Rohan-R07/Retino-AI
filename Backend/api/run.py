#!/usr/bin/env python3
"""
Server runner script for Retino-AI Backend API.
Run from anywhere:
    python3 Backend/api/run.py
"""

import sys
from pathlib import Path
import uvicorn

# Ensure Backend/api directory is in sys.path
api_dir = Path(__file__).resolve().parent
if str(api_dir) not in sys.path:
    sys.path.insert(0, str(api_dir))


def main():
    print("=" * 60)
    print("Starting Retino-AI FastAPI Server...")
    print("API Documentation : http://127.0.0.1:8000/docs")
    print("Alternative Docs  : http://127.0.0.1:8000/redoc")
    print("Health Check      : http://127.0.0.1:8000/api/health")
    print("=" * 60)

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        reload_dirs=[str(api_dir / "app")],
    )


if __name__ == "__main__":
    main()
