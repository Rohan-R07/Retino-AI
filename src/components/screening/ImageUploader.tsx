import { useState, useCallback, useRef } from "react";
import { Upload, Camera, X, FileImage } from "lucide-react";
import { cn } from "@/lib/utils";

interface ImageUploaderProps {
  onImageSelect: (file: File) => void;
  isUploading?: boolean;
  className?: string;
}

const ACCEPTED_TYPES = ["image/jpeg", "image/png", "image/jpg"];
const MAX_SIZE_MB = 10;
const MAX_SIZE_BYTES = MAX_SIZE_MB * 1024 * 1024;

/**
 * Large, obvious image upload area for retinal images.
 * Supports drag-and-drop and file selection.
 */
export function ImageUploader({
  onImageSelect,
  isUploading = false,
  className,
}: ImageUploaderProps) {
  const [isDragOver, setIsDragOver] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const validateAndSelect = useCallback(
    (file: File) => {
      setError(null);

      if (!ACCEPTED_TYPES.includes(file.type)) {
        setError("Please select a JPG or PNG image.");
        return;
      }

      if (file.size > MAX_SIZE_BYTES) {
        setError(`Image is too large. Maximum size is ${MAX_SIZE_MB} MB.`);
        return;
      }

      onImageSelect(file);
    },
    [onImageSelect]
  );

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      setIsDragOver(false);
      const file = e.dataTransfer.files[0];
      if (file) validateAndSelect(file);
    },
    [validateAndSelect]
  );

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragOver(true);
  };

  const handleDragLeave = () => {
    setIsDragOver(false);
  };

  const handleFileInput = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) validateAndSelect(file);
  };

  return (
    <div className={cn("space-y-4", className)}>
      {/* Drop zone */}
      <div
        onDrop={handleDrop}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        className={cn(
          "flex flex-col items-center justify-center gap-4 rounded-xl border-2 border-dashed p-8 sm:p-12 text-center transition-colors cursor-pointer",
          isDragOver
            ? "border-primary bg-primary-light"
            : "border-border bg-white hover:border-primary/50 hover:bg-gray-50",
          isUploading && "pointer-events-none opacity-60"
        )}
        onClick={() => fileInputRef.current?.click()}
        role="button"
        tabIndex={0}
        aria-label="Upload eye image"
        onKeyDown={(e) => {
          if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            fileInputRef.current?.click();
          }
        }}
      >
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-primary-light">
          <Upload className="h-8 w-8 text-primary" />
        </div>

        <div className="space-y-2">
          <h3 className="text-lg font-semibold text-foreground">
            Upload Eye Image
          </h3>
          <p className="text-muted-foreground">
            Take or select a clear image of the retina.
          </p>
        </div>

        <div className="flex flex-col items-center gap-3 sm:flex-row">
          <button
            type="button"
            className="inline-flex items-center gap-2 rounded-lg bg-primary px-5 py-3 text-base font-medium text-primary-foreground hover:bg-primary/90 transition-colors"
            onClick={(e) => {
              e.stopPropagation();
              fileInputRef.current?.click();
            }}
          >
            <FileImage className="h-5 w-5" />
            Choose Image
          </button>

          <button
            type="button"
            className="inline-flex items-center gap-2 rounded-lg border border-border bg-white px-5 py-3 text-base font-medium text-foreground hover:bg-muted transition-colors"
            onClick={(e) => {
              e.stopPropagation();
              // Camera integration would go here
              setError("Camera feature is not yet available. Please select an image file.");
            }}
          >
            <Camera className="h-5 w-5" />
            Use Camera
          </button>
        </div>

        <p className="text-sm text-muted-foreground">
          Supported formats: JPG, PNG · Max size: {MAX_SIZE_MB} MB
        </p>
      </div>

      {/* Error message */}
      {error && (
        <div className="flex items-center gap-2 rounded-lg border border-red-200 bg-red-50 px-4 py-3" role="alert">
          <X className="h-4 w-4 text-red-600 flex-shrink-0" />
          <p className="text-sm text-red-700">{error}</p>
        </div>
      )}

      {/* Hidden file input */}
      <input
        ref={fileInputRef}
        type="file"
        accept=".jpg,.jpeg,.png"
        onChange={handleFileInput}
        className="hidden"
        aria-hidden="true"
      />
    </div>
  );
}
