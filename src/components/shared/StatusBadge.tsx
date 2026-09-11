import { cn, getStatusColor, getStatusLabel, getSeverityColor } from "@/lib/utils";

interface StatusBadgeProps {
  status: string;
  variant?: "status" | "severity";
  className?: string;
}

/**
 * Pill badge for screening status or severity level.
 * Rounded-full pill shape matching the hospital UI aesthetic.
 */
export function StatusBadge({ status, variant = "status", className }: StatusBadgeProps) {
  const colorClasses =
    variant === "severity" ? getSeverityColor(status) : getStatusColor(status);
  const label = variant === "severity" ? status : getStatusLabel(status);

  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full border px-3 py-1 text-xs font-semibold",
        colorClasses,
        className
      )}
    >
      {/* Dot indicator */}
      <span className="mr-1.5 h-1.5 w-1.5 rounded-full bg-current opacity-70 inline-block" />
      {label}
    </span>
  );
}
