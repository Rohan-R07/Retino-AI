import { useState, type FormEvent } from "react";
import {
  CheckCircle2,
  ClipboardCheck,
  FileText,
  XCircle,
  AlertTriangle,
} from "lucide-react";
import {
  cn,
  formatConfidence,
  getSeverityLabel,
  getSeverityColor,
  getDecisionLabel,
} from "@/lib/utils";
import type {
  FullScreeningReport,
  DRSeverity,
  DoctorDecision,
  VerifyScreeningRequest,
} from "@/types";

interface DoctorReviewCardProps {
  screening: FullScreeningReport;
  onVerify: (payload: VerifyScreeningRequest) => void;
  isSubmitting?: boolean;
  className?: string;
}

const SEVERITY_OPTIONS: DRSeverity[] = [
  "No DR",
  "Mild",
  "Moderate",
  "Severe",
  "Proliferative DR",
];

const DECISION_OPTIONS: { value: DoctorDecision; label: string; description: string }[] = [
  {
    value: "confirmed",
    label: "Confirmed",
    description: "AI diagnosis is correct",
  },
  {
    value: "modified",
    label: "Modified",
    description: "AI diagnosis needs adjustment",
  },
  {
    value: "rejected",
    label: "Rejected",
    description: "AI diagnosis is incorrect",
  },
];

/**
 * Doctor verification panel — allows an ophthalmologist to confirm,
 * modify, or reject the AI screening result.
 * Payload aligns with POST /api/screenings/{id}/verify.
 */
export function DoctorReviewCard({
  screening,
  onVerify,
  isSubmitting = false,
  className,
}: DoctorReviewCardProps) {
  const aiSeverity = screening.severity ?? "No DR";

  const [decision, setDecision] = useState<DoctorDecision>("confirmed");
  const [finalSeverity, setFinalSeverity] = useState<DRSeverity>(aiSeverity);
  const [notes, setNotes] = useState("");

  const isVerified = screening.status === "verified";

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    onVerify({
      decision,
      final_severity: finalSeverity,
      notes: notes.trim() || undefined,
    });
  };

  // ── Already verified — display read-only summary ──────────────────

  if (isVerified && screening.doctor_verification) {
    const dv = screening.doctor_verification;
    const decisionIcon =
      dv.decision === "confirmed" ? (
        <CheckCircle2 className="h-6 w-6 text-green-600" />
      ) : dv.decision === "modified" ? (
        <AlertTriangle className="h-6 w-6 text-amber-600" />
      ) : (
        <XCircle className="h-6 w-6 text-red-600" />
      );

    const containerColor =
      dv.decision === "confirmed"
        ? "border-green-200 bg-green-50"
        : dv.decision === "modified"
          ? "border-amber-200 bg-amber-50"
          : "border-red-200 bg-red-50";

    const textColor =
      dv.decision === "confirmed"
        ? "text-green-800"
        : dv.decision === "modified"
          ? "text-amber-800"
          : "text-red-800";

    return (
      <div className={cn("rounded-xl border p-6", containerColor, className)}>
        <div className="flex items-center gap-3 mb-4">
          {decisionIcon}
          <h2 className={cn("text-lg font-semibold", textColor)}>
            {getDecisionLabel(dv.decision)} by Doctor
          </h2>
        </div>
        <dl className={cn("space-y-2 text-sm", textColor)}>
          <div>
            <dt className="font-medium inline">Decision: </dt>
            <dd className="inline">{getDecisionLabel(dv.decision)}</dd>
          </div>
          <div>
            <dt className="font-medium inline">Final Severity: </dt>
            <dd className="inline">{getSeverityLabel(dv.final_severity)}</dd>
          </div>
          {dv.notes && (
            <div>
              <dt className="font-medium inline">Notes: </dt>
              <dd className="inline">{dv.notes}</dd>
            </div>
          )}
          <div className="pt-1 text-xs opacity-70">
            Verified at: {dv.verification_timestamp}
          </div>
        </dl>
      </div>
    );
  }

  // ── Pending review — show form ────────────────────────────────────

  return (
    <div className={cn("rounded-xl border border-border bg-white p-6", className)}>
      <div className="flex items-center gap-3 mb-5">
        <ClipboardCheck className="h-6 w-6 text-primary" />
        <h2 className="text-lg font-semibold text-foreground">Doctor Review</h2>
      </div>

      {/* AI result summary */}
      {screening.severity && (
        <div
          className={cn(
            "rounded-lg border p-4 mb-6",
            getSeverityColor(screening.severity)
          )}
        >
          <p className="text-sm font-medium">AI Screening Result</p>
          <p className="text-base font-bold mt-1">
            {getSeverityLabel(screening.severity)}
          </p>
          {screening.confidence !== null && (
            <p className="text-sm mt-1">
              Confidence: {formatConfidence(screening.confidence)}
            </p>
          )}
          {screening.referable !== null && (
            <p className="text-xs mt-1 font-medium">
              {screening.referable ? "⚠ Referable" : "✓ Non-referable"}
            </p>
          )}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Decision */}
        <div className="space-y-2">
          <label className="block text-base font-medium text-foreground">
            Decision <span className="text-red-500">*</span>
          </label>
          <p className="text-sm text-muted-foreground">
            How does the AI result compare to your clinical assessment?
          </p>
          <div className="grid gap-2 sm:grid-cols-3">
            {DECISION_OPTIONS.map((opt) => (
              <label
                key={opt.value}
                className={cn(
                  "relative flex cursor-pointer flex-col rounded-lg border p-3 transition-colors",
                  decision === opt.value
                    ? "border-primary bg-primary/5 ring-1 ring-primary"
                    : "border-border hover:border-primary/40"
                )}
              >
                <input
                  type="radio"
                  name="decision"
                  value={opt.value}
                  checked={decision === opt.value}
                  onChange={() => setDecision(opt.value)}
                  className="sr-only"
                />
                <span className="text-sm font-semibold text-foreground">
                  {opt.label}
                </span>
                <span className="text-xs text-muted-foreground mt-0.5">
                  {opt.description}
                </span>
              </label>
            ))}
          </div>
        </div>

        {/* Final severity */}
        <div className="space-y-2">
          <label
            htmlFor="final-severity"
            className="block text-base font-medium text-foreground"
          >
            Final Severity <span className="text-red-500">*</span>
          </label>
          <p className="text-sm text-muted-foreground">
            Set the clinically confirmed severity grade.
          </p>
          <select
            id="final-severity"
            value={finalSeverity}
            onChange={(e) => setFinalSeverity(e.target.value as DRSeverity)}
            className="w-full rounded-lg border border-input bg-white px-4 py-3 text-base text-foreground focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
          >
            {SEVERITY_OPTIONS.map((level) => (
              <option key={level} value={level}>
                {getSeverityLabel(level)} ({level})
              </option>
            ))}
          </select>
        </div>

        {/* Notes */}
        <div className="space-y-2">
          <label
            htmlFor="review-notes"
            className="block text-base font-medium text-foreground"
          >
            <FileText className="inline h-4 w-4 mr-1" />
            Clinical Notes{" "}
            <span className="text-sm font-normal text-muted-foreground">
              (optional)
            </span>
          </label>
          <textarea
            id="review-notes"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={3}
            placeholder="e.g. Confirmed bilateral moderate NPDR. Schedule follow-up in 3 months."
            className="w-full rounded-lg border border-input bg-white px-4 py-3 text-base text-foreground placeholder:text-muted-foreground focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20 resize-y"
          />
        </div>

        {/* Submit */}
        <button
          type="submit"
          disabled={isSubmitting}
          className="w-full rounded-lg bg-primary px-6 py-3.5 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed sm:w-auto"
        >
          <ClipboardCheck className="inline h-5 w-5 mr-2" />
          {isSubmitting ? "Submitting..." : "Submit Verification"}
        </button>
      </form>
    </div>
  );
}
