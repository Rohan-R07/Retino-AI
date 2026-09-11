import { useState, useEffect } from "react";
import { useParams, Link } from "react-router-dom";
import { ArrowLeft } from "lucide-react";
import { ReportPreview } from "@/components/report/ReportPreview";
import { LoadingState } from "@/components/shared/LoadingState";
import { ErrorState } from "@/components/shared/ErrorState";
import type { FullScreeningReport } from "@/types";
import { getScreening, ApiError } from "@/api/screenings";

export function ReportPage() {
  const { id } = useParams<{ id: string }>();
  const [screening, setScreening] = useState<FullScreeningReport | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadScreening = async () => {
    if (!id) return;
    setIsLoading(true);
    setError(null);
    try {
      const data = await getScreening(id);
      setScreening(data);
    } catch (err) {
      if (err instanceof ApiError && err.code === "SCREENING_NOT_FOUND") {
        setError("This screening report does not exist.");
      } else {
        setError("Could not load report. Please try again.");
      }
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadScreening();
  }, [id]);

  if (isLoading) {
    return <LoadingState message="Preparing report..." className="p-6" />;
  }

  if (error || !screening) {
    return (
      <div className="p-6">
        <ErrorState
          title="Could not load report"
          message={error ?? "Report not found."}
          onRetry={loadScreening}
        />
      </div>
    );
  }

  return (
    <div className="p-4 sm:p-6 max-w-3xl mx-auto">
      <Link
        to={`/screening/${screening.screening_id}`}
        className="inline-flex items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground transition-colors mb-4 no-print"
      >
        <ArrowLeft className="h-4 w-4" />
        Back to Screening
      </Link>

      <ReportPreview screening={screening} />
    </div>
  );
}
