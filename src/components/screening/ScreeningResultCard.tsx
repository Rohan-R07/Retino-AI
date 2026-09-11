import { cn, formatConfidence, getSeverityLabel, getSeverityColor } from "@/lib/utils";
import type { SeverityLevel } from "@/types";
import { ConfidenceIndicator } from "./ConfidenceIndicator";

interface ScreeningResultCardProps {
  prediction: SeverityLevel;
  confidence: number;
  className?: string;
}

/**
 * Main screening result display — shows severity, confidence,
 * and a clear medical disclaimer.
 */
export function ScreeningResultCard({
  prediction,
  confidence,
  className,
}: ScreeningResultCardProps) {
  const severityColors = getSeverityColor(prediction);
  const label = getSeverityLabel(prediction);

  // Severity scale for visual reference
  const scale: SeverityLevel[] = [
    "No DR",
    "Mild",
    "Moderate",
    "Severe",
    "Proliferative",
  ];
  const activeIndex = scale.indexOf(prediction);

  return (
    <div className={cn("rounded-xl border border-border bg-white p-6", className)}>
      <h2 className="mb-4 text-lg font-semibold text-foreground">
        Screening Result
      </h2>

      {/* Main result */}
      <div className={cn("rounded-lg border p-5 mb-5", severityColors)}>
        <p className="text-xl font-bold">{label}</p>
        <p className="text-sm mt-1 opacity-80">
          Category: {prediction}
        </p>
      </div>

      {/* Confidence */}
      <div className="mb-5">
        <ConfidenceIndicator confidence={confidence} />
      </div>

      {/* Severity scale */}
      <div className="mb-5">
        <p className="text-sm font-medium text-muted-foreground mb-2">
          Severity Scale
        </p>
        <div className="flex gap-1">
          {scale.map((level, i) => (
            <div
              key={level}
              className={cn(
                "flex-1 rounded-md py-2 text-center text-xs font-medium transition-all",
                i === activeIndex
                  ? cn(getSeverityColor(level), "border ring-1 ring-current/30")
                  : "bg-gray-50 text-gray-400 border border-gray-100"
              )}
            >
              <span className="hidden sm:inline">{level}</span>
              <span className="sm:hidden">{i + 1}</span>
            </div>
          ))}
        </div>
        <div className="flex justify-between mt-1">
          <span className="text-xs text-muted-foreground sm:hidden">Low risk</span>
          <span className="text-xs text-muted-foreground sm:hidden">High risk</span>
        </div>
      </div>

      {/* Medical disclaimer */}
      <div className="rounded-lg border border-blue-200 bg-blue-50 p-4">
        <p className="text-sm text-blue-800">
          <strong>Important:</strong> This result is a screening aid and should
          be reviewed by a qualified healthcare professional. It is not a
          diagnosis.
        </p>
      </div>
    </div>
  );
}
