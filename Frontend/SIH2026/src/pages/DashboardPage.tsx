import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import {
  Activity,
  Clock,
  AlertTriangle,
  CheckCircle2,
  PlusCircle,
  Eye,
  ArrowRight,
  TrendingUp,
} from "lucide-react";
import { StatCard } from "@/components/dashboard/StatCard";
import { StatusBadge } from "@/components/shared/StatusBadge";
import { LoadingState } from "@/components/shared/LoadingState";
import { EmptyState } from "@/components/shared/EmptyState";
import type { ScreeningListItem, DashboardStats } from "@/types";
import { getDashboardStats, getRecentScreenings } from "@/api/screenings";
import { formatDate, getSeverityLabel, getStatusLabel } from "@/lib/utils";

export function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [screenings, setScreenings] = useState<ScreeningListItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      setIsLoading(true);
      setError(null);
      try {
        const [s, r] = await Promise.all([getDashboardStats(), getRecentScreenings()]);
        setStats(s);
        setScreenings(r);
      } catch {
        setError("Could not connect to the backend. Is the API server running at port 8000?");
      } finally {
        setIsLoading(false);
      }
    }
    load();
  }, []);

  if (isLoading) {
    return <LoadingState message="Loading dashboard..." />;
  }

  if (error) {
    return (
      <div className="p-6">
        <div className="rounded-2xl border border-red-200 bg-red-50 p-5 text-sm text-red-700">
          <p className="font-semibold mb-1">⚠ Backend Unreachable</p>
          <p>{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 p-4 sm:p-6">

      {/* ── Hero banner ──────────────────────────────────────────── */}
      <div
        className="relative overflow-hidden rounded-2xl px-6 py-8 sm:px-8 sm:py-10 text-white"
        style={{ background: "linear-gradient(135deg, #0E9DBF 0%, #0A7A96 55%, #076880 100%)" }}
      >
        {/* Dot pattern overlay */}
        <div className="absolute inset-0 dot-pattern opacity-20" />

        {/* ECG decoration */}
        <div className="absolute bottom-0 left-0 right-0 ecg-line opacity-20" />

        {/* Decorative circles */}
        <div className="absolute -right-8 -top-8 h-40 w-40 rounded-full bg-white/10" />
        <div className="absolute right-16 -bottom-12 h-32 w-32 rounded-full bg-white/5" />

        <div className="relative">
          <div className="inline-flex items-center gap-2 rounded-full bg-white/20 px-3 py-1 text-xs font-medium mb-3">
            <span className="h-1.5 w-1.5 rounded-full bg-white animate-pulse" />
            AI-Powered Retinal Analysis
          </div>
          <h1 className="text-2xl sm:text-3xl font-bold leading-tight mb-2">
            Diabetic Retinopathy<br />Screening System
          </h1>
          <p className="text-sm text-white/80 mb-5 max-w-md">
            Automated fundus image analysis with Random Forest AI for early detection and clinical referral support.
          </p>
          <Link
            to="/screening/new"
            className="inline-flex items-center gap-2 rounded-full bg-white px-5 py-2.5 text-sm font-semibold transition-all hover:bg-white/90 hover:shadow-lg"
            style={{ color: "#0A7A96" }}
          >
            <PlusCircle className="h-4 w-4" />
            Start New Screening
            <ArrowRight className="h-4 w-4" />
          </Link>
        </div>
      </div>

      {/* ── KPI stat cards ───────────────────────────────────────── */}
      {stats && (
        <div className="grid grid-cols-2 gap-3 sm:gap-4 lg:grid-cols-4">
          <StatCard
            title="Total Screenings"
            value={stats.total_screenings}
            icon={Activity}
            trend="All time"
          />
          <StatCard
            title="Pending Reviews"
            value={stats.pending_doctor_reviews}
            icon={Clock}
            iconBg="bg-amber-100"
            iconColor="text-amber-600"
            trend="Awaiting doctor"
          />
          <StatCard
            title="Referable Cases"
            value={stats.referable_cases}
            icon={AlertTriangle}
            iconBg="bg-red-100"
            iconColor="text-red-600"
            trend={`${stats.referable_percentage.toFixed(1)}% rate`}
            trendUp={false}
          />
          <StatCard
            title="Verified"
            value={stats.verified_screenings}
            icon={CheckCircle2}
            iconBg="bg-green-100"
            iconColor="text-green-600"
            trend="Completed"
            trendUp={true}
          />
        </div>
      )}

      {/* ── Referral rate bar ────────────────────────────────────── */}
      {stats && stats.total_screenings > 0 && (
        <div
          className="rounded-2xl bg-white p-5 sm:p-6"
          style={{ boxShadow: "0 2px 16px rgba(14,157,191,0.08)" }}
        >
          <div className="flex items-center justify-between mb-3">
            <div>
              <p className="text-sm font-semibold text-foreground">Referral Rate Overview</p>
              <p className="text-xs text-muted-foreground mt-0.5">
                {stats.referable_cases} referable · {stats.non_referable_cases} non-referable
              </p>
            </div>
            <div className="flex items-center gap-1.5 rounded-full px-3 py-1.5" style={{ background: "#E0F5FA" }}>
              <TrendingUp className="h-4 w-4" style={{ color: "#0E9DBF" }} />
              <span className="text-sm font-bold" style={{ color: "#0A7A96" }}>
                {stats.referable_percentage.toFixed(1)}%
              </span>
            </div>
          </div>
          {/* Progress bar */}
          <div className="h-3 rounded-full bg-muted overflow-hidden">
            <div
              className="h-full rounded-full transition-all duration-700"
              style={{
                width: `${stats.referable_percentage}%`,
                background: "linear-gradient(90deg, #0E9DBF 0%, #0A7A96 100%)",
              }}
            />
          </div>
          <div className="flex justify-between mt-2 text-xs text-muted-foreground">
            <span>0%</span>
            <span>100%</span>
          </div>
        </div>
      )}

      {/* ── Recent screenings ────────────────────────────────────── */}
      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-bold text-foreground">Recent Screenings</h2>
          <Link
            to="/patients"
            className="text-sm font-medium flex items-center gap-1 hover:underline"
            style={{ color: "#0E9DBF" }}
          >
            View all <ArrowRight className="h-3.5 w-3.5" />
          </Link>
        </div>

        {screenings.length === 0 ? (
          <div
            className="rounded-2xl bg-white"
            style={{ boxShadow: "0 2px 16px rgba(14,157,191,0.08)" }}
          >
            <EmptyState
              title="No screenings yet"
              message="Start a new screening to see results here."
              icon={<Eye className="h-6 w-6 text-white" />}
              action={
                <Link
                  to="/screening/new"
                  className="inline-flex items-center gap-2 rounded-full px-5 py-2.5 text-sm font-semibold text-white transition-all"
                  style={{ background: "linear-gradient(135deg, #0E9DBF 0%, #0A7A96 100%)" }}
                >
                  <PlusCircle className="h-4 w-4" />
                  New Screening
                </Link>
              }
            />
          </div>
        ) : (
          <div
            className="rounded-2xl bg-white overflow-hidden"
            style={{ boxShadow: "0 2px 16px rgba(14,157,191,0.08)" }}
          >
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border" style={{ background: "#F0F7FA" }}>
                    <th className="px-5 py-3.5 text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                      Patient
                    </th>
                    <th className="px-5 py-3.5 text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                      Date
                    </th>
                    <th className="px-5 py-3.5 text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                      Severity
                    </th>
                    <th className="px-5 py-3.5 text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                      Status
                    </th>
                    <th className="px-5 py-3.5 text-left text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                      Action
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {screenings.map((s) => (
                    <tr
                      key={s.screening_id}
                      className="border-b border-border last:border-0 transition-colors"
                      style={{ cursor: "pointer" }}
                      onMouseEnter={(e) =>
                        ((e.currentTarget as HTMLTableRowElement).style.background = "#F0F7FA")
                      }
                      onMouseLeave={(e) =>
                        ((e.currentTarget as HTMLTableRowElement).style.background = "")
                      }
                    >
                      <td className="px-5 py-4">
                        <p className="font-semibold text-foreground">{s.patient_name}</p>
                        <p className="text-xs text-muted-foreground font-mono mt-0.5">
                          {s.patient_id}
                        </p>
                      </td>
                      <td className="px-5 py-4 text-muted-foreground text-sm">
                        {formatDate(s.timestamp)}
                      </td>
                      <td className="px-5 py-4">
                        {s.severity ? (
                          <StatusBadge status={s.severity} variant="severity" />
                        ) : (
                          <span className="text-xs text-muted-foreground">—</span>
                        )}
                      </td>
                      <td className="px-5 py-4">
                        <StatusBadge status={s.status} />
                      </td>
                      <td className="px-5 py-4">
                        <Link
                          to={`/screening/${s.screening_id}`}
                          className="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-semibold text-white transition-all hover:shadow-md"
                          style={{ background: "linear-gradient(135deg, #0E9DBF 0%, #0A7A96 100%)" }}
                        >
                          <Eye className="h-3.5 w-3.5" />
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
      </div>
    </div>
  );
}
