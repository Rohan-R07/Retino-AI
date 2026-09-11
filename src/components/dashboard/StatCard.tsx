import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";

interface StatCardProps {
  title: string;
  value: number | string;
  icon: LucideIcon;
  iconColor?: string;
  iconBg?: string;
  trend?: string;
  trendUp?: boolean;
  className?: string;
}

/**
 * Dashboard KPI card — premium medical healthcare style.
 * Rounded corners, soft shadow, teal accent.
 */
export function StatCard({
  title,
  value,
  icon: Icon,
  iconColor = "text-white",
  iconBg = "",
  trend,
  trendUp,
  className,
}: StatCardProps) {
  return (
    <div
      className={cn(
        "relative overflow-hidden rounded-2xl bg-white p-5 sm:p-6 transition-all duration-200",
        className
      )}
      style={{ boxShadow: "0 2px 16px rgba(14,157,191,0.08), 0 1px 4px rgba(14,157,191,0.05)" }}
    >
      {/* Decorative circle */}
      <div
        className="absolute -right-4 -top-4 h-24 w-24 rounded-full opacity-10"
        style={{ background: "linear-gradient(135deg, #0E9DBF, #0A7A96)" }}
      />

      <div className="relative flex items-start justify-between gap-4">
        <div className="flex-1 min-w-0">
          <p className="text-xs font-semibold uppercase tracking-wider" style={{ color: "#5B7A8A" }}>
            {title}
          </p>
          <p className="mt-1.5 text-3xl font-bold text-foreground leading-none">
            {value}
          </p>
          {trend && (
            <p
              className="mt-2 text-xs font-medium"
              style={{ color: trendUp ? "#16A34A" : "#DC2626" }}
            >
              {trendUp ? "↑" : "↓"} {trend}
            </p>
          )}
        </div>

        <div
          className={cn(
            "flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-xl",
            iconBg
          )}
          style={
            !iconBg
              ? { background: "linear-gradient(135deg, #0E9DBF 0%, #0A7A96 100%)" }
              : undefined
          }
        >
          <Icon className={cn("h-6 w-6", iconColor || "text-white")} />
        </div>
      </div>
    </div>
  );
}
