import { X } from "lucide-react";
import { cn } from "@/lib/utils";

interface ImagePreviewProps {
  src: string;
  alt?: string;
  onRemove?: () => void;
  className?: string;
}

/**
 * Large image preview after an image has been selected or uploaded.
 */
export function ImagePreview({
  src,
  alt = "Uploaded eye image",
  onRemove,
  className,
}: ImagePreviewProps) {
  return (
    <div className={cn("relative rounded-xl border border-border bg-white overflow-hidden", className)}>
      <img
        src={src}
        alt={alt}
        className="w-full max-h-96 object-contain bg-gray-50"
        loading="lazy"
      />
      {onRemove && (
        <button
          onClick={onRemove}
          className="absolute top-3 right-3 flex h-10 w-10 items-center justify-center rounded-full bg-white border border-border text-foreground hover:bg-red-50 hover:text-red-600 hover:border-red-200 transition-colors"
          aria-label="Remove image"
        >
          <X className="h-5 w-5" />
        </button>
      )}
    </div>
  );
}
