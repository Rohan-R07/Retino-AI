import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/** Format an ISO date string to a human-readable format */
export function formatDate(iso: string): string {
  const date = new Date(iso);
  return date.toLocaleDateString("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}

/** Format an ISO date string to include time */
export function formatDateTime(iso: string): string {
  const date = new Date(iso);
  return date.toLocaleString("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

/** Convert a confidence float (0–1) to a percentage string */
export function formatConfidence(confidence: number): string {
  return `${Math.round(confidence * 100)}%`;
}

/** Get a human-readable label for severity */
export function getSeverityLabel(severity: string): string {
  const labels: Record<string, string> = {
    "No DR": "No signs detected",
    Mild: "Mild signs detected",
    Moderate: "Moderate signs detected",
    Severe: "Severe signs detected",
    "Proliferative DR": "Advanced signs detected",
    // Legacy alias — kept so old mock data still renders correctly
    Proliferative: "Advanced signs detected",
  };
  return labels[severity] ?? severity;
}

/** Get the Tailwind color classes for a severity level */
export function getSeverityColor(severity: string): string {
  switch (severity) {
    case "No DR":
      return "text-green-700 bg-green-50 border-green-200";
    case "Mild":
      return "text-yellow-700 bg-yellow-50 border-yellow-200";
    case "Moderate":
      return "text-amber-700 bg-amber-50 border-amber-200";
    case "Severe":
      return "text-red-700 bg-red-50 border-red-200";
    case "Proliferative DR":
    case "Proliferative": // legacy alias
      return "text-red-800 bg-red-100 border-red-300";
    default:
      return "text-gray-700 bg-gray-50 border-gray-200";
  }
}

/** Whether a severity level is considered referable */
export function isReferable(severity: string): boolean {
  return ["Moderate", "Severe", "Proliferative DR", "Proliferative"].includes(
    severity
  );
}

/** Get the Tailwind color classes for a screening status */
export function getStatusColor(status: string): string {
  switch (status) {
    case "created":
      return "text-gray-700 bg-gray-50 border-gray-200";
    case "analyzing":
      return "text-blue-700 bg-blue-50 border-blue-200";
    case "analyzed":
      return "text-amber-700 bg-amber-50 border-amber-200";
    case "verified":
      return "text-green-700 bg-green-50 border-green-200";
    // Legacy statuses — kept so old mock data still renders
    case "completed":
      return "text-blue-700 bg-blue-50 border-blue-200";
    case "pending_review":
      return "text-amber-700 bg-amber-50 border-amber-200";
    case "reviewed":
      return "text-green-700 bg-green-50 border-green-200";
    case "processing":
      return "text-blue-700 bg-blue-50 border-blue-200";
    case "uploading":
      return "text-gray-700 bg-gray-50 border-gray-200";
    default:
      return "text-gray-700 bg-gray-50 border-gray-200";
  }
}

/** Human-readable status labels */
export function getStatusLabel(status: string): string {
  const labels: Record<string, string> = {
    created: "Created",
    analyzing: "Analyzing",
    analyzed: "Awaiting Review",
    verified: "Verified",
    // Legacy aliases
    uploading: "Uploading",
    processing: "Processing",
    completed: "Completed",
    pending_review: "Pending Review",
    reviewed: "Reviewed",
  };
  return labels[status] ?? status;
}

/** Human-readable doctor decision labels */
export function getDecisionLabel(decision: string): string {
  const labels: Record<string, string> = {
    confirmed: "Confirmed",
    modified: "Modified",
    rejected: "Rejected",
  };
  return labels[decision] ?? decision;
}
