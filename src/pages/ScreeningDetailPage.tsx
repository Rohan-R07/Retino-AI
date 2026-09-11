import { useState, useEffect } from "react";
import { useParams, Link } from "react-router-dom";
import { ArrowLeft, Eye, ClipboardCheck, FileText } from "lucide-react";
import { DoctorReviewCard } from "@/components/review/DoctorReviewCard";
import { LoadingState } from "@/components/shared/LoadingState";
import { ErrorState } from "@/components/shared/ErrorState";
import type { FullScreeningReport, VerifyScreeningRequest } from "@/types";
import { getScreening, verifyScreening, ApiError } from "@/api/screenings";
import { getSeverityLabel, getSeverityColor, getStatusLabel, formatConfidence, cn } from "@/lib/utils";

type Tab = "result" | "evidence" | "review";

export function ScreeningDetailPage() {
  const { id } = useParams<{ id: string }>();
  const [screening, setScreening] = useState<FullScreeningReport | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<Tab>("result");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const loadScreening = async () => {
    if (!id) return;
    setIsLoading(true);
    setError(null);
    try {
      const data = await getScreening(id);
      setScreening(data);
    } catch (err) {
      if (err instanceof ApiError && err.code === "SCREENING_NOT_FOUND") {
        setError("This screening does not exist.");
      } else {
        setError("Could not load screening details. Please try again.");
      }
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadScreening();
  }, [id]);

  const handleVerify = async (payload: VerifyScreeningRequest) => {
    if (!id || !screening) return;
    setIsSubmitting(true);
    try {
      const dv = await verifyScreening(id, payload);
      // Merge the verification back into screening state without a full reload
      setScreening((prev) =>
        prev
          ? {
              ...prev,
              status: "verified",
              doctor_verification: dv,
              doctor_decision: dv.decision,
              final_severity: dv.final_severity,
              doctor_notes: dv.notes,
              verification_timestamp: dv.verification_timestamp,
            }
          : prev
      );
      setActiveTab("result");
    } catch {
      setError("Could not submit review. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  if (isLoading) {
    return <LoadingState message="Loading screening details..." className="p-6" />;
  }

  if (error || !screening) {
    return (
      <div className="p-6">
        <ErrorState
          title="Could not load screening"
          message={error ?? "Screening not found."}
          onRetry={loadScreening}
        />
      </div>
    );
  }

  const tabs: { key: Tab; label: string; icon: typeof Eye }[] = [
    { key: "result", label: "Result", icon: Eye },
    { key: "evidence", label: "Findings", icon: FileText },
    { key: "review", label: "Doctor Review", icon: ClipboardCheck },
  ];

  const canReview = screening.status === "analyzed";

  return (
    <div className="p-4 sm:p-6 max-w-3xl mx-auto">
      {/* Back link */}
      <Link
        to="/"
        className="inline-flex items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground transition-colors mb-4"
      >
        <ArrowLeft className="h-4 w-4" />
        Back to Dashboard
      </Link>

      {/* Header */}
      <div className="mb-5">
        <h1 className="text-xl font-bold text-foreground">
          Screening #{screening.screening_id}
        </h1>
        <p className="text-sm text-muted-foreground">
          {screening.patient.name} · {screening.patient_id} · Age{" "}
          {screening.patient.age} · {screening.patient.gender}
        </p>
      </div>

      {/* Tab navigation */}
      <div className="flex border-b border-border mb-6 overflow-x-auto">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          return (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              className={`flex items-center gap-2 px-4 py-3 text-sm font-medium border-b-2 transition-colors whitespace-nowrap ${
                activeTab === tab.key
                  ? "border-primary text-primary"
                  : "border-transparent text-muted-foreground hover:text-foreground hover:border-border"
              }`}
            >
              <Icon className="h-4 w-4" />
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* Result tab */}
      {activeTab === "result" && (
        <div className="space-y-6">
          {/* Status banner */}
          <div className="flex items-center gap-3 rounded-lg border border-border bg-muted/30 px-4 py-3">
            <span className="text-sm text-muted-foreground">Status:</span>
            <span className="text-sm font-semibold text-foreground">
              {getStatusLabel(screening.status)}
            </span>
          </div>

          {/* AI result card */}
          {screening.severity ? (
            <div
              className={cn(
                "rounded-xl border p-5",
                getSeverityColor(screening.severity)
              )}
            >
              <p className="text-sm font-medium mb-1">AI Diagnosis</p>
              <p className="text-2xl font-bold">
                {getSeverityLabel(screening.severity)}
              </p>
              <p className="text-sm mt-1">
                {screening.severity} (Level {screening.severity_level})
              </p>
              {screening.confidence !== null && (
                <p className="text-sm mt-1">
                  Confidence: {formatConfidence(screening.confidence)}
                </p>
              )}
              {screening.referable !== null && (
                <p className="text-xs mt-2 font-semibold">
                  {screening.referable
                    ? "⚠ Referable — specialist consultation recommended"
                    : "✓ Non-referable"}
                </p>
              )}
              {screening.image_quality && (
                <p className="text-xs mt-1 opacity-75">
                  Image Quality: {screening.image_quality}
                </p>
              )}
            </div>
          ) : (
            <div className="rounded-xl border border-border bg-muted/30 p-5 text-center text-muted-foreground">
              AI analysis not yet run.
            </div>
          )}

          {/* Quick actions */}
          <div className="flex flex-wrap gap-3">
            {canReview && (
              <button
                onClick={() => setActiveTab("review")}
                className="inline-flex items-center gap-2 rounded-lg bg-primary px-5 py-3 text-sm font-medium text-primary-foreground hover:bg-primary/90 transition-colors"
              >
                <ClipboardCheck className="h-4 w-4" />
                Submit Doctor Review
              </button>
            )}

            {screening.findings.length > 0 && (
              <button
                onClick={() => setActiveTab("evidence")}
                className="inline-flex items-center gap-2 rounded-lg border border-border bg-white px-5 py-3 text-sm font-medium text-foreground hover:bg-muted transition-colors"
              >
                <Eye className="h-4 w-4" />
                View Findings
              </button>
            )}

            <Link
              to={`/screening/${screening.screening_id}/report`}
              className="inline-flex items-center gap-2 rounded-lg border border-border bg-white px-5 py-3 text-sm font-medium text-foreground hover:bg-muted transition-colors"
            >
              <FileText className="h-4 w-4" />
              View Report
            </Link>
          </div>

          {/* Verified summary */}
          {screening.status === "verified" && screening.doctor_verification && (
            <DoctorReviewCard
              screening={screening}
              onVerify={handleVerify}
            />
          )}
        </div>
      )}

      {/* Findings tab */}
      {activeTab === "evidence" && (
        <div className="space-y-4">
          <h2 className="text-base font-semibold text-foreground">
            Clinical Findings
          </h2>

          {screening.image_url && (
            <div className="rounded-xl border border-border overflow-hidden">
              <img
                src={screening.image_url}
                alt="Fundus image"
                className="w-full object-cover max-h-72"
              />
            </div>
          )}

          {screening.findings.length > 0 ? (
            <ul className="space-y-2">
              {screening.findings.map((finding, idx) => (
                <li
                  key={idx}
                  className="rounded-lg border border-border bg-white px-4 py-3 text-sm text-foreground"
                >
                  {finding}
                </li>
              ))}
            </ul>
          ) : (
            <p className="text-sm text-muted-foreground">
              No specific findings recorded.
            </p>
          )}
        </div>
      )}

      {/* Review tab */}
      {activeTab === "review" && (
        <DoctorReviewCard
          screening={screening}
          onVerify={handleVerify}
          isSubmitting={isSubmitting}
        />
      )}
    </div>
  );
}
