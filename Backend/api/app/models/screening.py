from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base


class Screening(Base):
    __tablename__ = "screenings"

    screening_id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    patient_id = Column(String(64), ForeignKey("patients.patient_id", ondelete="CASCADE"), nullable=False, index=True)
    image_path = Column(String(512), nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False)
    status = Column(String(32), default="created", nullable=False)  # "created", "analyzed", "verified", "failed"

    # Relationships
    patient = relationship("Patient", back_populates="screenings")
    result = relationship("ScreeningResult", back_populates="screening", uselist=False, cascade="all, delete-orphan")
    verification = relationship("DoctorVerification", back_populates="screening", uselist=False, cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Screening(id={self.screening_id}, patient_id={self.patient_id}, status={self.status})>"
