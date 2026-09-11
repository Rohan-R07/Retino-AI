import { Printer, CheckCircle2, AlertTriangle, XCircle } from "lucide-react";
import type { FullScreeningReport } from "@/types";
import {
  cn,
  formatDateTime,
  formatConfidence,
  getSeverityLabel,
  getSeverityColor,
  getDecisionLabel,
} from "@/lib/utils";

interface ReportPreviewProps {
  screening: FullScreeningReport;
  className?: string;
}

/**
 * Clean, printable screening report.
 * When report_data is available (post-verification) it uses the structured
 * report object for richer output. Falls back gracefully to raw screening fields.
 */
export function ReportPreview({ screening, className }: ReportPreviewProps) {
  const rd = screening.report_data;

  const displaySeverity = rd?.diagnosis.final_severity ?? screening.final_severity ?? screening.severity;
  const displayFindings = rd?.clinical_findings ?? screening.findings ?? [];
  const displayConfidence = rd?.diagnosis.confidence ?? screening.confidence;
  const displayPatient = rd?.patient ?? {
    id: screening.patient_id,
    name: screening.patient.name,
    age: screening.patient.age,
    gender: screening.patient.gender,
  };

  return (
    <div className={cn("space-y-6", className)}>
      {/* Action buttons — hidden on print */}
      <div className="flex flex-wrap gap-3 no-print">
        <button
          onClick={() => window.print()}
          className="inline-flex items-center gap-2 rounded-lg bg-primary px-5 py-3 text-base font-medium text-primary-foreground hover:bg-primary/90 transition-colors"
        >
          <Printer className="h-5 w-5" />
          Print / Download Report
        </button>
      </div>

      {/* Report content */}
      <div className="rounded-xl border border-border bg-white p-6 sm:p-8">
        {/* Header */}
        <div className="border-b border-border pb-5 mb-5">
          <div className="flex items-start justify-between gap-4">
            <div>
              <h1 className="text-xl font-bold text-foreground">
                Diabetic Retinopathy Screening Report
              </h1>
              <p className="text-sm text-muted-foreground mt-1">
                Screening support for early detection and referral
              </p>
            </div>
            {rd?.report_id && (
              <span className="text-xs font-mono text-muted-foreground bg-muted rounded px-2 py-1 shrink-0">
                {rd.report_id}
              </span>
            )}
          </div>
        </div>

        {/* Patient + Screening Info */}
        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 mb-6">
          {/* Patient */}
          <div className="space-y-3">
            <h2 className="text-base font-semibold text-foreground">
              Patient Information
            </h2>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Name</dt>
                <dd className="font-medium text-foreground">
                  {displayPatient.name}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Patient ID</dt>
                <dd className="font-medium text-foreground font-mono">
                  {displayPatient.id}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Age</dt>
                <dd className="font-medium text-foreground">
                  {displayPatient.age} years
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Gender</dt>
                <dd className="font-medium text-foreground">
                  {displayPatient.gender}
                </dd>
              </div>
            </dl>
          </div>

          {/* Screening */}
          <div className="space-y-3">
            <h2 className="text-base font-semibold text-foreground">
              Screening Information
            </h2>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Screening ID</dt>
                <dd className="font-medium text-foreground">
                  #{screening.screening_id}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Date</dt>
                <dd className="font-medium text-foreground">
                  {formatDateTime(screening.timestamp)}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Image Quality</dt>
                <dd className="font-medium text-foreground">
                  {screening.image_quality ?? "—"}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-muted-foreground">Status</dt>
                <dd className="font-medium text-foreground capitalize">
                  {screening.status}
                </dd>
              </div>
            </dl>
          </div>
        </div>

        {/* AI Diagnosis */}
        {displaySeverity && (
          <div className="mb-6">
            <h2 className="text-base font-semibold text-foreground mb-3">
              Diagnosis
            </h2>
            <div
              className={cn(
                "rounded-lg border p-4",
                getSeverityColor(displaySeverity)
              )}
            >
              <p className="text-lg font-bold">
                {getSeverityLabel(displaySeverity)}
              </p>
              <p className="text-sm mt-1">Grade: {displaySeverity}</p>
              {displayConfidence !== null && displayConfidence !== undefined && (
                <p className="text-sm mt-1">
                  AI Confidence: {formatConfidence(displayConfidence)}
                </p>
              )}
              {screening.referable !== null && (
                <p className="text-xs mt-2 font-semibold">
                  {screening.referable
                    ? "⚠ Referable — specialist consultation recommended"
                    : "✓ Non-referable"}
                </p>
              )}
            </div>
          </div>
        )}

        {/* Clinical Recommendation (from report_data) */}
        {rd?.recommendation && (
          <div className="mb-6 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3">
            <p className="text-sm font-semibold text-amber-800 mb-1">
              Clinical Recommendation
            </p>
            <p className="text-sm text-amber-700">{rd.recommendation}</p>
          </div>
        )}

        {/* Clinical Findings */}
        {displayFindings.length > 0 && (
          <div className="mb-6 border-t border-border pt-5">
            <h2 className="text-base font-semibold text-foreground mb-3">
              Clinical Findings
            </h2>
            <ul className="space-y-2">
              {displayFindings.map((finding, idx) => (
                <li
                  key={idx}
                  className="rounded-lg border border-border p-3 text-sm text-foreground"
                >
                  {finding}
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* Doctor Verification */}
        <div className="border-t border-border pt-5">
          <h2 className="text-base font-semibold text-foreground mb-3">
            Doctor Verification
          </h2>
          {screening.doctor_verification ? (
            <div
              className={cn(
                "rounded-lg border p-4 space-y-2",
                screening.doctor_verification.decision === "confirmed"
                  ? "border-green-200 bg-green-50"
                  : screening.doctor_verification.decision === "modified"
                    ? "border-amber-200 bg-amber-50"
                    : "border-red-200 bg-red-50"
              )}
            >
              <div className="flex items-center gap-2">
                {screening.doctor_verification.decision === "confirmed" ? (
                  <CheckCircle2 className="h-5 w-5 text-green-600" />
                ) : screening.doctor_verification.decision === "modified" ? (
                  <AlertTriangle className="h-5 w-5 text-amber-600" />
                ) : (
                  <XCircle className="h-5 w-5 text-red-600" />
                )}
                <span className="font-medium text-sm">
                  {getDecisionLabel(screening.doctor_verification.decision)}
                </span>
              </div>
              <p className="text-sm">
                Final Grade:{" "}
                <strong>
                  {getSeverityLabel(screening.doctor_verification.final_severity)}
                </strong>
              </p>
              {screening.doctor_verification.notes && (
                <p className="text-sm">
                  Notes: {screening.doctor_verification.notes}
                </p>
              )}
              <p className="text-xs opacity-70">
                Verified: {formatDateTime(screening.doctor_verification.verification_timestamp)}
              </p>
            </div>
          ) : (
            <p className="text-sm text-amber-700 bg-amber-50 border border-amber-200 rounded-lg p-3">
              Pending doctor review
            </p>
          )}
        </div>

        {/* Disclaimer */}
        <div className="mt-6 border-t border-border pt-5">
          <p className="text-xs text-muted-foreground">
            This report is generated by a screening support tool and is intended
            to assist qualified healthcare professionals. It should not be
            treated as a standalone medical diagnosis. All clinical decisions
            must be made by a licensed healthcare professional.
          </p>
          {rd?.generated_at ? (
            <p className="text-xs text-muted-foreground mt-2">
              Generated at: {formatDateTime(rd.generated_at)}
            </p>
          ) : (
            <p className="text-xs text-muted-foreground mt-2">
              Generated on {formatDateTime(new Date().toISOString())}
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
