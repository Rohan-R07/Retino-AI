from datetime import datetime
from sqlalchemy import Column, String, Integer, DateTime
from sqlalchemy.orm import relationship
from app.database import Base


class Patient(Base):
    __tablename__ = "patients"

    patient_id = Column(String(64), primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    age = Column(Integer, nullable=False)
    gender = Column(String(32), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    screenings = relationship("Screening", back_populates="patient", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Patient(patient_id={self.patient_id}, name={self.name})>"
