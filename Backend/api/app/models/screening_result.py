import json
from datetime import datetime
from typing import List, Optional
from sqlalchemy import Column, Integer, String, Float, Boolean, Text, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base


class ScreeningResult(Base):
    __tablename__ = "screening_results"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    screening_id = Column(Integer, ForeignKey("screenings.screening_id", ondelete="CASCADE"), unique=True, nullable=False, index=True)
    image_quality = Column(String(32), nullable=False, default="Good")
    severity = Column(String(64), nullable=False)  # "No DR", "Mild", "Moderate", "Severe", "Proliferative DR"
    severity_level = Column(Integer, nullable=False, default=0)  # 0 to 4
    confidence = Column(Float, nullable=False)  # e.g. 0.91
    referable = Column(Boolean, nullable=False, default=False)
    findings_json = Column("findings", Text, nullable=False, default="[]")
    evidence_image = Column(String(512), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    screening = relationship("Screening", back_populates="result")

    @property
    def findings(self) -> List[str]:
        """Deserialize findings from JSON text."""
        try:
            return json.loads(self.findings_json) if self.findings_json else []
        except Exception:
            return []

    @findings.setter
    def findings(self, value: List[str]):
        """Serialize findings list into JSON text."""
        self.findings_json = json.dumps(value if value is not None else [])

    def __repr__(self):
        return f"<ScreeningResult(screening_id={self.screening_id}, severity={self.severity}, confidence={self.confidence})>"
