import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { ClipboardCheck, Eye } from "lucide-react";
import { StatusBadge } from "@/components/shared/StatusBadge";
import { LoadingState } from "@/components/shared/LoadingState";
import { EmptyState } from "@/components/shared/EmptyState";
import type { ScreeningListItem } from "@/types";
import { getPendingReviews } from "@/api/screenings";
import { formatDate, getSeverityLabel } from "@/lib/utils";

export function PendingReviewsPage() {
  const [screenings, setScreenings] = useState<ScreeningListItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    async function load() {
      setIsLoading(true);
      try {
        const data = await getPendingReviews();
        setScreenings(data);
      } finally {
        setIsLoading(false);
      }
    }
    load();
  }, []);

  if (isLoading) {
    return <LoadingState message="Loading pending reviews..." />;
  }

  return (
    <div className="p-4 sm:p-6 space-y-5">
      <div className="lg:hidden">
        <h1 className="text-xl font-bold text-foreground">Pending Reviews</h1>
        <p className="text-sm text-muted-foreground">
          Screenings awaiting doctor verification.
        </p>
      </div>

      {screenings.length === 0 ? (
        <EmptyState
          title="No pending reviews"
          message="All screenings have been reviewed."
          icon={<ClipboardCheck className="h-7 w-7 text-muted-foreground" />}
        />
      ) : (
        <>
          <p className="text-sm text-muted-foreground">
            {screenings.length} screening{screenings.length !== 1 ? "s" : ""}{" "}
            waiting for review
          </p>

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
                        #{s.screening_id}
                      </span>
                      {s.severity && (
                        <StatusBadge status={s.severity} variant="severity" />
                      )}
                    </div>
                    <p className="text-sm text-muted-foreground">
                      {s.patient_name} · {s.patient_id} ·{" "}
                      {formatDate(s.timestamp)}
                      {s.severity && ` · ${getSeverityLabel(s.severity)}`}
                    </p>
                  </div>
                  <Link
                    to={`/screening/${s.screening_id}`}
                    className="inline-flex items-center gap-2 rounded-lg bg-primary px-5 py-2.5 text-sm font-medium text-primary-foreground hover:bg-primary/90 transition-colors self-start"
                  >
                    <Eye className="h-4 w-4" />
                    Review
                  </Link>
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
