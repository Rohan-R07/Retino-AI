#!/usr/bin/env python3
"""
Test runner script for Retino-AI Backend API.
Usage:
    python3 Backend/api/run_tests.py
"""

import sys
from pathlib import Path
import pytest

# Ensure Backend/api directory is in sys.path
api_dir = Path(__file__).resolve().parent
if str(api_dir) not in sys.path:
    sys.path.insert(0, str(api_dir))

if __name__ == "__main__":
    tests_path = str(api_dir / "tests")
    cache_path = str(api_dir / ".pytest_cache")
    print(f"Running Retino-AI API test suite in {tests_path}...\n")
    exit_code = pytest.main(["-v", "-s", "-o", f"cache_dir={cache_path}", tests_path])
    sys.exit(exit_code)
