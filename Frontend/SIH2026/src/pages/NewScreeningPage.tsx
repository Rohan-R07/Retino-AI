import { useState, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { ArrowLeft, ChevronRight } from "lucide-react";
import { PatientForm, type PatientFormData } from "@/components/screening/PatientForm";
import { ImageUploader } from "@/components/screening/ImageUploader";
import { ImagePreview } from "@/components/screening/ImagePreview";
import { ScreeningProgress } from "@/components/screening/ScreeningProgress";
import { ErrorState } from "@/components/shared/ErrorState";
import { createScreening, analyzeScreening, ApiError } from "@/api/screenings";

type Step = "patient-info" | "upload-image" | "processing";

// Maps ApiError codes to user-friendly messages
function errorMessage(err: unknown): string {
  if (err instanceof ApiError) {
    switch (err.code) {
      case "INVALID_IMAGE":
        return "The image could not be read. Please upload a valid retinal fundus image.";
      case "IMAGE_TOO_LARGE":
        return "The image exceeds the 20 MB size limit. Please compress and retry.";
      case "UNSUPPORTED_FORMAT":
        return "Unsupported file format. Please upload a .jpg, .jpeg, .png, .tif, or .tiff file.";
      case "AI_ANALYSIS_FAILED":
        return "The AI engine failed to process the image. Please try again.";
      case "PATIENT_NOT_FOUND":
        return "Patient record could not be found. Please re-enter patient details.";
      default:
        return err.message;
    }
  }
  return "An unexpected error occurred. Please try again or contact the support team.";
}

export function NewScreeningPage() {
  const navigate = useNavigate();
  const [step, setStep] = useState<Step>("patient-info");
  const [patientData, setPatientData] = useState<PatientFormData | null>(null);
  const [selectedImage, setSelectedImage] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [processingStage, setProcessingStage] = useState(0);
  const [error, setError] = useState<string | null>(null);

  // Step 1: Patient info submitted
  const handlePatientSubmit = (data: PatientFormData) => {
    setPatientData(data);
    setStep("upload-image");
  };

  // Step 2: Image selected — just preview it, no quality check call
  const handleImageSelect = useCallback((file: File) => {
    setSelectedImage(file);
    setImagePreview(URL.createObjectURL(file));
    setError(null);
  }, []);

  const handleRemoveImage = () => {
    if (imagePreview) URL.revokeObjectURL(imagePreview);
    setSelectedImage(null);
    setImagePreview(null);
  };

  // Step 3: Upload → Analyze → Navigate
  const handleStartScreening = async () => {
    if (!patientData || !selectedImage) return;

    setStep("processing");
    setIsProcessing(true);
    setError(null);
    setProcessingStage(0);

    try {
      // Stage 1: Upload image & create screening record
      setProcessingStage(1);
      const created = await createScreening({
        name: patientData.name,
        age: patientData.age,
        gender: patientData.gender,
        patient_id: patientData.patient_id,
        image: selectedImage,
      });

      // Stage 2: Trigger AI inference
      setProcessingStage(2);
      await analyzeScreening(created.screening_id);

      // Stage 3: Done
      setProcessingStage(3);

      setTimeout(() => {
        navigate(`/screening/${created.screening_id}`);
      }, 800);
    } catch (err) {
      setError(errorMessage(err));
      setStep("upload-image");
      setIsProcessing(false);
    }
  };

  const getProcessingSteps = () => [
    {
      label: "Image received",
      status:
        processingStage >= 1 ? ("completed" as const) : ("pending" as const),
    },
    {
      label: "Uploading to server",
      status:
        processingStage >= 2
          ? ("completed" as const)
          : processingStage === 1
            ? ("active" as const)
            : ("pending" as const),
    },
    {
      label: "AI analysis in progress",
      status:
        processingStage >= 3
          ? ("completed" as const)
          : processingStage === 2
            ? ("active" as const)
            : ("pending" as const),
    },
    { label: "Doctor review", status: "pending" as const },
  ];

  const stepLabels = [
    { key: "patient-info", label: "Patient Info" },
    { key: "upload-image", label: "Upload Image" },
    { key: "processing", label: "Screening" },
  ];
  const currentStepIndex = stepLabels.findIndex((s) => s.key === step);

  return (
    <div className="p-4 sm:p-6 max-w-2xl mx-auto">
      {/* Page header */}
      <div className="mb-6">
        <div className="lg:hidden mb-2">
          <h1 className="text-xl font-bold text-foreground">New Screening</h1>
          <p className="text-sm text-muted-foreground">
            Follow the steps to complete a screening.
          </p>
        </div>

        {/* Step indicator */}
        <div className="flex items-center gap-2 mb-6" aria-label="Progress">
          {stepLabels.map((s, i) => (
            <div key={s.key} className="flex items-center gap-2">
              <div className="flex items-center gap-2">
                <div
                  className={`flex h-8 w-8 items-center justify-center rounded-full text-sm font-semibold ${
                    i <= currentStepIndex
                      ? "bg-primary text-primary-foreground"
                      : "bg-muted text-muted-foreground"
                  }`}
                >
                  {i + 1}
                </div>
                <span
                  className={`text-sm font-medium hidden sm:inline ${
                    i <= currentStepIndex
                      ? "text-foreground"
                      : "text-muted-foreground"
                  }`}
                >
                  {s.label}
                </span>
              </div>
              {i < stepLabels.length - 1 && (
                <ChevronRight className="h-4 w-4 text-muted-foreground" />
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Error display */}
      {error && (
        <ErrorState
          title="Something went wrong"
          message={error}
          onRetry={() => setError(null)}
          className="mb-6"
        />
      )}

      {/* Step 1: Patient Info */}
      {step === "patient-info" && (
        <div className="rounded-xl border border-border bg-white p-5 sm:p-6">
          <h2 className="text-lg font-semibold text-foreground mb-1">
            Patient Information
          </h2>
          <p className="text-sm text-muted-foreground mb-5">
            Enter basic information about the patient.
          </p>
          <PatientForm onSubmit={handlePatientSubmit} />
        </div>
      )}

      {/* Step 2: Upload Image */}
      {step === "upload-image" && (
        <div className="space-y-4">
          {/* Back button */}
          <button
            onClick={() => setStep("patient-info")}
            className="inline-flex items-center gap-2 text-sm font-medium text-muted-foreground hover:text-foreground transition-colors"
          >
            <ArrowLeft className="h-4 w-4" />
            Back to Patient Info
          </button>

          {/* Patient summary */}
          {patientData && (
            <div className="rounded-xl border border-border bg-white p-4">
              <p className="text-sm text-muted-foreground">
                <strong className="text-foreground">{patientData.name}</strong>
                {patientData.patient_id && (
                  <>
                    {" · "}
                    <span className="font-mono">{patientData.patient_id}</span>
                  </>
                )}
                {" · "}Age:{" "}
                <strong className="text-foreground">{patientData.age}</strong>
                {" · "}
                <strong className="text-foreground">{patientData.gender}</strong>
              </p>
            </div>
          )}

          {/* Upload area or preview */}
          {!selectedImage ? (
            <ImageUploader onImageSelect={handleImageSelect} />
          ) : (
            <div className="space-y-4">
              <ImagePreview src={imagePreview!} onRemove={handleRemoveImage} />

              {/* Start screening button */}
              <button
                onClick={handleStartScreening}
                disabled={isProcessing}
                className="w-full rounded-lg bg-primary px-6 py-3.5 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed sm:w-auto"
              >
                {isProcessing ? "Processing..." : "Start Screening"}
              </button>
            </div>
          )}
        </div>
      )}

      {/* Step 3: Processing */}
      {step === "processing" && (
        <div className="rounded-xl border border-border bg-white p-6 sm:p-8 text-center">
          <h2 className="text-lg font-semibold text-foreground mb-2">
            Analyzing Eye Image
          </h2>
          <p className="text-muted-foreground mb-6">
            Please wait while the AI engine processes the retinal image.
          </p>
          <ScreeningProgress
            steps={getProcessingSteps()}
            className="text-left max-w-xs mx-auto"
          />
        </div>
      )}
    </div>
  );
}
