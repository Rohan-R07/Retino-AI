import { CheckCircle2, AlertTriangle } from "lucide-react";
import type { ImageQualityCheck } from "@/types";
import { cn } from "@/lib/utils";

interface ImageQualityCardProps {
  quality: ImageQualityCheck;
  className?: string;
}

/**
 * Simple checklist showing image quality assessment results.
 * Uses plain language, not technical terminology.
 */
export function ImageQualityCard({ quality, className }: ImageQualityCardProps) {
  const checks = [
    { label: "Image is clear", passed: quality.is_clear },
    { label: "Eye is visible", passed: quality.eye_visible },
    { label: "Image is suitable for screening", passed: quality.suitable_for_screening },
  ];

  const allPassed = checks.every((c) => c.passed);

  return (
    <div
      className={cn(
        "rounded-xl border p-5",
        allPassed
          ? "border-green-200 bg-green-50"
          : "border-amber-200 bg-amber-50",
        className
      )}
    >
      <h3 className="mb-3 text-base font-semibold text-foreground">
        Image Quality
      </h3>

      <ul className="space-y-2">
        {checks.map((check) => (
          <li key={check.label} className="flex items-center gap-3">
            {check.passed ? (
              <CheckCircle2 className="h-5 w-5 flex-shrink-0 text-green-600" />
            ) : (
              <AlertTriangle className="h-5 w-5 flex-shrink-0 text-amber-600" />
            )}
            <span
              className={cn(
                "text-sm",
                check.passed ? "text-green-800" : "text-amber-800"
              )}
            >
              {check.passed ? "✓" : "⚠"} {check.label}
            </span>
          </li>
        ))}
      </ul>

      {!allPassed && (
        <p className="mt-3 text-sm text-amber-700">
          Image may be unclear. Please upload another image.
        </p>
      )}
    </div>
  );
}
