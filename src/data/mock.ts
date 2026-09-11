import type {
  Screening,
  DashboardStats,
  ImageQualityCheck,
} from "@/types";

// ── Sample retinal images (public domain placeholders) ───────────────
// In production these will be actual patient images stored on the server.
const PLACEHOLDER_RETINA = "/placeholder-retina.svg";

// ── Mock screenings ─────────────────────────────────────────────────

export const mockScreenings: Screening[] = [
  {
    screening_id: "DR-2026-001",
    patient_id: "P-1001",
    patient_age: 54,
    patient_sex: "male",
    prediction: "Moderate",
    confidence: 0.91,
    image_quality: "Good",
    original_image_url: PLACEHOLDER_RETINA,
    heatmap_url: PLACEHOLDER_RETINA,
    evidence: [
      {
        id: "e1",
        label: "Microaneurysms",
        description: "Small red dots found in the central area of the retina.",
      },
      {
        id: "e2",
        label: "Hard Exudates",
        description:
          "Yellow deposits detected near the macula region.",
      },
    ],
    status: "pending_review",
    created_at: "2026-09-09T10:30:00Z",
  },
  {
    screening_id: "DR-2026-002",
    patient_id: "P-1002",
    patient_age: 47,
    patient_sex: "female",
    prediction: "No DR",
    confidence: 0.96,
    image_quality: "Good",
    original_image_url: PLACEHOLDER_RETINA,
    evidence: [],
    status: "reviewed",
    doctor_review: {
      reviewer_name: "Dr. Priya Sharma",
      reviewed_at: "2026-09-09T11:15:00Z",
      confirmed_prediction: "No DR",
      notes: "Normal retina. No signs of diabetic retinopathy.",
      referral_recommended: false,
    },
    created_at: "2026-09-09T09:15:00Z",
  },
  {
    screening_id: "DR-2026-003",
    patient_id: "P-1003",
    patient_age: 62,
    patient_sex: "male",
    prediction: "Severe",
    confidence: 0.87,
    image_quality: "Fair",
    original_image_url: PLACEHOLDER_RETINA,
    heatmap_url: PLACEHOLDER_RETINA,
    evidence: [
      {
        id: "e3",
        label: "Hemorrhages",
        description: "Multiple blot hemorrhages across several quadrants.",
      },
      {
        id: "e4",
        label: "Cotton Wool Spots",
        description: "Soft, white patches indicating nerve fiber damage.",
      },
      {
        id: "e5",
        label: "Venous Beading",
        description: "Irregular vein caliber changes observed.",
      },
    ],
    status: "pending_review",
    created_at: "2026-09-09T08:45:00Z",
  },
  {
    screening_id: "DR-2026-004",
    patient_id: "P-1004",
    patient_age: 39,
    patient_sex: "female",
    prediction: "Mild",
    confidence: 0.83,
    image_quality: "Good",
    original_image_url: PLACEHOLDER_RETINA,
    evidence: [
      {
        id: "e6",
        label: "Microaneurysms",
        description: "A few small microaneurysms detected.",
      },
    ],
    status: "reviewed",
    doctor_review: {
      reviewer_name: "Dr. Rajesh Kumar",
      reviewed_at: "2026-09-09T12:00:00Z",
      confirmed_prediction: "Mild",
      notes: "Early signs. Recommend follow-up in 6 months.",
      referral_recommended: false,
    },
    created_at: "2026-09-08T14:20:00Z",
  },
  {
    screening_id: "DR-2026-005",
    patient_id: "P-1005",
    patient_age: 58,
    patient_sex: "male",
    prediction: "Proliferative",
    confidence: 0.94,
    image_quality: "Good",
    original_image_url: PLACEHOLDER_RETINA,
    heatmap_url: PLACEHOLDER_RETINA,
    evidence: [
      {
        id: "e7",
        label: "Neovascularization",
        description: "New abnormal blood vessel growth detected.",
      },
      {
        id: "e8",
        label: "Vitreous Hemorrhage",
        description: "Bleeding into the vitreous detected.",
      },
    ],
    status: "pending_review",
    created_at: "2026-09-08T11:00:00Z",
  },
  {
    screening_id: "DR-2026-006",
    patient_id: "P-1006",
    patient_age: 45,
    patient_sex: "female",
    prediction: "No DR",
    confidence: 0.98,
    image_quality: "Good",
    original_image_url: PLACEHOLDER_RETINA,
    evidence: [],
    status: "completed",
    created_at: "2026-09-08T09:30:00Z",
  },
];

// ── Dashboard stats ──────────────────────────────────────────────────

export const mockDashboardStats: DashboardStats = {
  screenings_today: 4,
  pending_reviews: 3,
  high_risk_cases: 2,
  completed_screenings: 12,
};

// ── Image quality check (mock result) ────────────────────────────────

export const mockGoodImageQuality: ImageQualityCheck = {
  is_clear: true,
  eye_visible: true,
  suitable_for_screening: true,
  overall: "Good",
};

export const mockPoorImageQuality: ImageQualityCheck = {
  is_clear: false,
  eye_visible: true,
  suitable_for_screening: false,
  overall: "Poor",
};
