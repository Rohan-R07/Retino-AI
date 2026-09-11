import { cn } from "@/lib/utils";
import type { EvidenceItem } from "@/types";

interface EvidenceViewerProps {
  originalImageUrl: string;
  heatmapUrl?: string;
  evidence: EvidenceItem[];
  className?: string;
}

/**
 * Side-by-side (or stacked on mobile) display of original and highlighted images.
 * Frontend only displays what the backend provides — no client-side computation.
 */
export function EvidenceViewer({
  originalImageUrl,
  heatmapUrl,
  evidence,
  className,
}: EvidenceViewerProps) {
  return (
    <div className={cn("space-y-6", className)}>
      <div>
        <h2 className="text-lg font-semibold text-foreground">
          Visual Evidence
        </h2>
        <p className="text-sm text-muted-foreground mt-1">
          Highlighted areas show regions that influenced the screening result.
        </p>
      </div>

      {/* Image comparison */}
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <div className="space-y-2">
          <h3 className="text-sm font-medium text-muted-foreground">
            Original Image
          </h3>
          <div className="rounded-xl border border-border bg-gray-50 overflow-hidden">
            <img
              src={originalImageUrl}
              alt="Original retinal image"
              className="w-full h-auto max-h-80 object-contain"
              loading="lazy"
            />
          </div>
        </div>

        {heatmapUrl && (
          <div className="space-y-2">
            <h3 className="text-sm font-medium text-muted-foreground">
              Highlighted Areas
            </h3>
            <div className="rounded-xl border border-border bg-gray-50 overflow-hidden">
              <img
                src={heatmapUrl}
                alt="Highlighted areas on retinal image"
                className="w-full h-auto max-h-80 object-contain"
                loading="lazy"
              />
            </div>
          </div>
        )}
      </div>

      {/* Evidence findings */}
      {evidence.length > 0 && (
        <div>
          <h3 className="text-sm font-medium text-foreground mb-3">
            Findings
          </h3>
          <ul className="space-y-3">
            {evidence.map((item) => (
              <li
                key={item.id}
                className="rounded-lg border border-border bg-white p-4"
              >
                <p className="font-medium text-foreground">{item.label}</p>
                <p className="text-sm text-muted-foreground mt-1">
                  {item.description}
                </p>
              </li>
            ))}
          </ul>
        </div>
      )}

      {evidence.length === 0 && (
        <p className="text-sm text-muted-foreground">
          No specific findings to display for this screening.
        </p>
      )}
    </div>
  );
}
