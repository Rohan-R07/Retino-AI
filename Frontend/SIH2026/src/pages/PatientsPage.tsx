import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { Search, Eye } from "lucide-react";
import { StatusBadge } from "@/components/shared/StatusBadge";
import { LoadingState } from "@/components/shared/LoadingState";
import { EmptyState } from "@/components/shared/EmptyState";
import type { Screening } from "@/types";
import { getAllScreenings } from "@/api/screenings";
import { formatDate } from "@/lib/utils";

export function PatientsPage() {
  const [screenings, setScreenings] = useState<Screening[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => {
    async function load() {
      setIsLoading(true);
      try {
        const data = await getAllScreenings();
        setScreenings(data);
      } finally {
        setIsLoading(false);
      }
    }
    load();
  }, []);

  const filtered = screenings.filter(
    (s) =>
      s.patient_id.toLowerCase().includes(searchQuery.toLowerCase()) ||
      s.screening_id.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (isLoading) {
    return <LoadingState message="Loading screenings..." />;
  }

  return (
    <div className="p-4 sm:p-6 space-y-5">
      <div className="lg:hidden">
        <h1 className="text-xl font-bold text-foreground">All Screenings</h1>
        <p className="text-sm text-muted-foreground">
          View and search past screenings.
        </p>
      </div>

      {/* Search */}
      <div className="relative max-w-md">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-muted-foreground" />
        <input
          type="text"
          placeholder="Search by Patient ID or Screening ID..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="w-full rounded-lg border border-input bg-white pl-10 pr-4 py-3 text-base text-foreground placeholder:text-muted-foreground focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
        />
      </div>

      {/* Table */}
      {filtered.length === 0 ? (
        <EmptyState
          title={searchQuery ? "No results found" : "No screenings yet"}
          message={
            searchQuery
              ? "Try a different search term."
              : "Start a new screening to see results here."
          }
        />
      ) : (
        <div className="rounded-xl border border-border bg-white overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-muted/50">
                  <th className="px-4 py-3 text-left font-medium text-muted-foreground">
                    Screening ID
                  </th>
                  <th className="px-4 py-3 text-left font-medium text-muted-foreground">
                    Patient ID
                  </th>
                  <th className="px-4 py-3 text-left font-medium text-muted-foreground">
                    Date
                  </th>
                  <th className="px-4 py-3 text-left font-medium text-muted-foreground">
                    Result
                  </th>
                  <th className="px-4 py-3 text-left font-medium text-muted-foreground">
                    Status
                  </th>
                  <th className="px-4 py-3 text-left font-medium text-muted-foreground">
                    Action
                  </th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((s) => (
                  <tr
                    key={s.screening_id}
                    className="border-b border-border last:border-0 hover:bg-muted/30 transition-colors"
                  >
                    <td className="px-4 py-3 font-medium text-foreground">
                      {s.screening_id}
                    </td>
                    <td className="px-4 py-3 text-foreground">
                      {s.patient_id}
                    </td>
                    <td className="px-4 py-3 text-muted-foreground">
                      {formatDate(s.created_at)}
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge status={s.prediction} variant="severity" />
                    </td>
                    <td className="px-4 py-3">
                      <StatusBadge status={s.status} />
                    </td>
                    <td className="px-4 py-3">
                      <Link
                        to={`/screening/${s.screening_id}`}
                        className="inline-flex items-center gap-1 text-primary hover:underline font-medium"
                      >
                        <Eye className="h-4 w-4" />
                        View
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      <p className="text-sm text-muted-foreground">
        Showing {filtered.length} of {screenings.length} screenings
      </p>
    </div>
  );
}
