import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { FileText } from "lucide-react";
import { StatusBadge } from "@/components/shared/StatusBadge";
import { LoadingState } from "@/components/shared/LoadingState";
import { EmptyState } from "@/components/shared/EmptyState";
import type { Screening } from "@/types";
import { getAllScreenings } from "@/api/screenings";
import { formatDate } from "@/lib/utils";

export function ReportsListPage() {
  const [screenings, setScreenings] = useState<Screening[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    async function load() {
      setIsLoading(true);
      try {
        const data = await getAllScreenings();
        // Only show screenings that have results
        setScreenings(
          data.filter(
            (s) => s.status === "completed" || s.status === "pending_review" || s.status === "reviewed"
          )
        );
      } finally {
        setIsLoading(false);
      }
    }
    load();
  }, []);

  if (isLoading) {
    return <LoadingState message="Loading reports..." />;
  }

  return (
    <div className="p-4 sm:p-6 space-y-5">
      <div className="lg:hidden">
        <h1 className="text-xl font-bold text-foreground">Reports</h1>
        <p className="text-sm text-muted-foreground">
          View and print screening reports.
        </p>
      </div>

      {screenings.length === 0 ? (
        <EmptyState
          title="No reports available"
          message="Complete a screening to generate a report."
          icon={<FileText className="h-7 w-7 text-muted-foreground" />}
        />
      ) : (
        <div className="space-y-3">
          {screenings.map((s) => (
            <div
              key={s.screening_id}
              className="rounded-xl border border-border bg-white p-4 sm:p-5 hover:border-primary/30 transition-colors"
            >
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <span className="font-semibold text-foreground">
                      {s.screening_id}
                    </span>
                    <StatusBadge
                      status={s.prediction}
                      variant="severity"
                    />
                    <StatusBadge status={s.status} />
                  </div>
                  <p className="text-sm text-muted-foreground">
                    Patient {s.patient_id} · {formatDate(s.created_at)}
                  </p>
                </div>
                <Link
                  to={`/screening/${s.screening_id}/report`}
                  className="inline-flex items-center gap-2 rounded-lg border border-border bg-white px-5 py-2.5 text-sm font-medium text-foreground hover:bg-muted transition-colors self-start"
                >
                  <FileText className="h-4 w-4" />
                  View Report
                </Link>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
