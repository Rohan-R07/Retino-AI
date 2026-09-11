import { Inbox } from "lucide-react";
import { cn } from "@/lib/utils";

interface EmptyStateProps {
  title?: string;
  message?: string;
  icon?: React.ReactNode;
  action?: React.ReactNode;
  className?: string;
}

export function EmptyState({
  title = "No data yet",
  message = "There is nothing to display at the moment.",
  icon,
  action,
  className,
}: EmptyStateProps) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center gap-5 py-16 text-center",
        className
      )}
    >
      {/* Icon with dot-pattern bg */}
      <div
        className="relative flex h-20 w-20 items-center justify-center rounded-2xl dot-pattern"
        style={{ background: "linear-gradient(135deg, #E0F5FA 0%, #C8EDF6 100%)" }}
      >
        <div
          className="flex h-12 w-12 items-center justify-center rounded-xl"
          style={{ background: "linear-gradient(135deg, #0E9DBF 0%, #0A7A96 100%)" }}
        >
          {icon ?? <Inbox className="h-6 w-6 text-white" />}
        </div>
      </div>

      <div className="space-y-1.5">
        <h3 className="text-lg font-bold text-foreground">{title}</h3>
        <p className="text-sm text-muted-foreground max-w-xs">{message}</p>
      </div>

      {action && <div className="mt-1">{action}</div>}
    </div>
  );
}
