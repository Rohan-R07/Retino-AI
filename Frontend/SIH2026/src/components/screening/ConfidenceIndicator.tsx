import { cn, formatConfidence } from "@/lib/utils";

interface ConfidenceIndicatorProps {
  confidence: number; // 0–1
  className?: string;
}

/**
 * Visual confidence bar with percentage.
 * Does NOT present confidence as medical certainty.
 */
export function ConfidenceIndicator({
  confidence,
  className,
}: ConfidenceIndicatorProps) {
  const percentage = Math.round(confidence * 100);

  // Color based on confidence level
  const barColor =
    percentage >= 85
      ? "bg-green-500"
      : percentage >= 70
        ? "bg-amber-500"
        : "bg-red-500";

  return (
    <div className={cn("space-y-2", className)}>
      <div className="flex items-center justify-between">
        <span className="text-sm font-medium text-foreground">
          Confidence
        </span>
        <span className="text-sm font-semibold text-foreground">
          {formatConfidence(confidence)}
        </span>
      </div>
      <div className="h-3 w-full rounded-full bg-gray-100">
        <div
          className={cn("h-3 rounded-full transition-all", barColor)}
          style={{ width: `${percentage}%` }}
          role="progressbar"
          aria-valuenow={percentage}
          aria-valuemin={0}
          aria-valuemax={100}
          aria-label={`Confidence: ${percentage}%`}
        />
      </div>
      <p className="text-xs text-muted-foreground">
        Confidence indicates how certain the screening model is about the result.
        It is not a measure of medical accuracy.
      </p>
    </div>
  );
}
