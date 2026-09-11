import { CheckCircle2, Circle, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";

type StepStatus = "completed" | "active" | "pending";

interface Step {
  label: string;
  status: StepStatus;
}

interface ScreeningProgressProps {
  steps: Step[];
  className?: string;
}

/**
 * Simple progress timeline for the screening process.
 * Shows: ✓ completed, ● active (loading), ○ pending
 */
export function ScreeningProgress({ steps, className }: ScreeningProgressProps) {
  return (
    <div className={cn("space-y-3", className)} role="progressbar" aria-label="Screening progress">
      {steps.map((step, index) => (
        <div key={index} className="flex items-center gap-3">
          {step.status === "completed" && (
            <CheckCircle2 className="h-6 w-6 flex-shrink-0 text-green-600" />
          )}
          {step.status === "active" && (
            <Loader2 className="h-6 w-6 flex-shrink-0 text-primary animate-spin" />
          )}
          {step.status === "pending" && (
            <Circle className="h-6 w-6 flex-shrink-0 text-gray-300" />
          )}
          <span
            className={cn(
              "text-base",
              step.status === "completed" && "text-green-700 font-medium",
              step.status === "active" && "text-primary font-semibold",
              step.status === "pending" && "text-muted-foreground"
            )}
          >
            {step.label}
          </span>
        </div>
      ))}
    </div>
  );
}
