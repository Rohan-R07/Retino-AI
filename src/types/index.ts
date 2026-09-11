// ── Severity & Status enums ──────────────────────────────────────────

export type DRSeverity =
  | "No DR"
  | "Mild"
  | "Moderate"
  | "Severe"
  | "Proliferative DR";

/** @deprecated Use DRSeverity. Kept for gradual migration. */
export type SeverityLevel = DRSeverity;

export type ScreeningStatus =
  | "created"
  | "analyzing"
  | "analyzed"
  | "verified";

export type ImageQuality = "Good" | "Adequate" | "Poor";

export type DoctorDecision = "confirmed" | "modified" | "rejected";

// ── Patient ──────────────────────────────────────────────────────────

export interface Patient {
  patient_id: string;
  name: string;
  age: number;
  gender: "Male" | "Female" | "Other";
  created_at: string;
}

// ── Doctor Verification ──────────────────────────────────────────────

export interface DoctorVerification {
  screening_id: number;
  decision: DoctorDecision;
  final_severity: DRSeverity;
  notes: string;
  verification_timestamp: string;
}

// ── Report data (nested inside full screening response) ──────────────

export interface ReportData {
  report_id: string;
  generated_at: string;
  patient: {
    id: string;
    name: string;
    age: number;
    gender: string;
  };
  diagnosis: {
    ai_severity: DRSeverity;
    final_severity: DRSeverity;
    referable: boolean;
    confidence: number;
    doctor_decision: DoctorDecision;
    doctor_notes: string;
  };
  clinical_findings: string[];
  recommendation: string;
}

// ── Full screening (GET /api/screenings/{id}) ────────────────────────

export interface FullScreeningReport {
  screening_id: number;
  patient_id: string;
  patient: Patient;
  image_url: string;
  image_path: string;
  status: ScreeningStatus;
  timestamp: string;
  image_quality: ImageQuality | null;
  severity: DRSeverity | null;
  severity_level: number | null;
  confidence: number | null;
  referable: boolean | null;
  findings: string[];
  evidence_image: string | null;
  doctor_verification: DoctorVerification | null;
  doctor_decision: DoctorDecision | null;
  final_severity: DRSeverity | null;
  doctor_notes: string | null;
  verification_timestamp: string | null;
  report_data: ReportData | null;
}

// ── Screening list item (GET /api/screenings) ────────────────────────

export interface ScreeningListItem {
  screening_id: number;
  patient_id: string;
  patient_name: string;
  patient_age: number;
  patient_gender: string;
  image_url: string;
  status: ScreeningStatus;
  timestamp: string;
  severity: DRSeverity | null;
  severity_level: number | null;
  confidence: number | null;
  referable: boolean | null;
  image_quality: ImageQuality | null;
  is_verified: boolean;
  verified_severity: DRSeverity | null;
}

// ── Screening upload response (POST /api/screenings) ─────────────────

export interface CreateScreeningResponse {
  screening_id: number;
  patient_id: string;
  status: "created";
}

// ── AI analysis result (POST /api/screenings/{id}/analyze) ───────────

export interface AIAnalysisResult {
  severity: DRSeverity;
  confidence: number;
  referable: boolean;
  image_quality: ImageQuality;
  findings: string[];
  evidence_image: string | null;
  severity_level: number;
}

// ── Request types ────────────────────────────────────────────────────

export interface CreateScreeningRequest {
  name: string;
  age: number;
  gender: "Male" | "Female" | "Other";
  patient_id?: string;
  image: File;
}

export interface VerifyScreeningRequest {
  decision: DoctorDecision;
  final_severity: DRSeverity;
  notes?: string;
}

// ── Dashboard stats (GET /api/dashboard/stats) ───────────────────────

export interface DashboardStats {
  total_screenings: number;
  total_patients: number;
  referable_cases: number;
  non_referable_cases: number;
  referable_percentage: number;
  pending_doctor_reviews: number;
  verified_screenings: number;
  severity_distribution: Record<DRSeverity, number>;
  image_quality_distribution: Record<ImageQuality, number>;
}

// ── Health check (GET /api/health) ───────────────────────────────────

export interface HealthResponse {
  status: "ok";
  service: string;
  ai_engine_provider: "real" | "mock";
}

// ── API Error ────────────────────────────────────────────────────────

export interface ApiErrorResponse {
  error: string;
  message: string;
}

// ── Legacy compatibility shims (used by existing components) ──────────
// These keep older component props compiling before they are individually updated.

/** @deprecated Use FullScreeningReport instead */
export interface Screening {
  screening_id: string;
  patient_id: string;
  patient_name?: string;
  patient_age: number;
  patient_sex: "male" | "female" | "other";
  /** Maps to `severity` from the API */
  prediction: DRSeverity;
  confidence: number;
  image_quality: ImageQuality;
  original_image_url: string;
  heatmap_url?: string;
  evidence: { id: string; label: string; description: string }[];
  status: ScreeningStatus;
  /** Populated after doctor verification */
  doctor_review?: {
    reviewer_name: string;
    reviewed_at: string;
    confirmed_prediction: DRSeverity;
    notes: string;
    referral_recommended: boolean;
  };
  created_at: string;
}

/** @deprecated Use ImageQuality directly */
export interface ImageQualityCheck {
  is_clear: boolean;
  eye_visible: boolean;
  suitable_for_screening: boolean;
  overall: ImageQuality;
}
