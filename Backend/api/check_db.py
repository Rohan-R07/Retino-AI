#!/usr/bin/env python3
"""
Quick utility script to test database connectivity and display table stats.
Run from anywhere:
    python3 Backend/api/check_db.py
"""

import sys
from pathlib import Path

# Ensure Backend/api is in sys.path
api_dir = Path(__file__).resolve().parent
if str(api_dir) not in sys.path:
    sys.path.insert(0, str(api_dir))

from sqlalchemy import inspect, select, func
from app.database import engine, init_db, SessionLocal
from app.config import DATABASE_URL
from app.models.patient import Patient
from app.models.screening import Screening
from app.models.screening_result import ScreeningResult
from app.models.doctor_verification import DoctorVerification


def check_database():
    print("=" * 60)
    print("       Retino-AI Database Diagnostic Tool")
    print("=" * 60)
    print(f"Connecting to: {DATABASE_URL}\n")

    try:
        # 1. Initialize tables if not already created
        init_db()
        inspector = inspect(engine)
        tables = inspector.get_table_names()

        print(" Connection Status :  CONNECTED")
        print(f" Tables Found ({len(tables)})  : {', '.join(tables)}\n")

        # 2. Count records in each table
        session = SessionLocal()
        try:
            p_count = session.scalar(select(func.count()).select_from(Patient)) or 0
            s_count = session.scalar(select(func.count()).select_from(Screening)) or 0
            r_count = session.scalar(select(func.count()).select_from(ScreeningResult)) or 0
            v_count = session.scalar(select(func.count()).select_from(DoctorVerification)) or 0

            print("--- Record Counts ---")
            print(f"  • patients             : {p_count} records")
            print(f"  • screenings           : {s_count} records")
            print(f"  • screening_results    : {r_count} records")
            print(f"  • doctor_verifications : {v_count} records\n")

            # 3. Show recent patients if available
            recent_patients = session.scalars(select(Patient).limit(3)).all()
            if recent_patients:
                print("--- Recent Patients Sample ---")
                for p in recent_patients:
                    print(f"  • ID: {p.patient_id:<14} Name: {p.name:<18} Age: {p.age:<3} Gender: {p.gender}")
            else:
                print("  (No patients found yet. Add one via POST /api/screenings)")

        finally:
            session.close()

        print("\n" + "=" * 60)
        print(" Database is healthy and ready for API operations!")
        print("=" * 60)

    except Exception as e:
        print(" Connection Status :  FAILED")
        print(f"Error Details     : {e}")
        print("=" * 60)


if __name__ == "__main__":
    check_database()
