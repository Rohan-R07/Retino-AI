from datetime import datetime
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base


class DoctorVerification(Base):
    __tablename__ = "doctor_verifications"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    screening_id = Column(Integer, ForeignKey("screenings.screening_id", ondelete="CASCADE"), unique=True, nullable=False, index=True)
    decision = Column(String(64), nullable=False)  # "confirmed", "modified", "rejected"
    final_severity = Column(String(64), nullable=False)
    notes = Column(Text, nullable=True)
    verification_timestamp = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    screening = relationship("Screening", back_populates="verification")

    def __repr__(self):
        return f"<DoctorVerification(screening_id={self.screening_id}, decision={self.decision}, final_severity={self.final_severity})>"
