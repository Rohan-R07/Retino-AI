import { Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

interface LoadingStateProps {
  message?: string;
  className?: string;
}

export function LoadingState({
  message = "Loading...",
  className,
}: LoadingStateProps) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center gap-4 py-16 text-center",
        className
      )}
      role="status"
      aria-live="polite"
    >
      {/* Pulse ring around spinner */}
      <div className="relative">
        <div
          className="absolute inset-0 rounded-full animate-pulse opacity-30"
          style={{ background: "radial-gradient(circle, #0E9DBF, transparent 70%)" }}
        />
        <div
          className="flex h-14 w-14 items-center justify-center rounded-full"
          style={{ background: "linear-gradient(135deg, #E0F5FA 0%, #C8EDF6 100%)" }}
        >
          <Loader2 className="h-7 w-7 animate-spin" style={{ color: "#0E9DBF" }} />
        </div>
      </div>
      <div>
        <p className="text-base font-semibold text-foreground">{message}</p>
        <p className="text-sm text-muted-foreground mt-0.5">Please wait a moment</p>
      </div>
    </div>
  );
}
