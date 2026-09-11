/**
 * API service layer — Retino-AI Screenings
 *
 * All functions call the FastAPI backend at http://127.0.0.1:8000.
 * Error responses follow the standard shape: { error: string, message: string }.
 */

import type {
  FullScreeningReport,
  ScreeningListItem,
  CreateScreeningRequest,
  CreateScreeningResponse,
  AIAnalysisResult,
  VerifyScreeningRequest,
  DoctorVerification,
  DashboardStats,
  HealthResponse,
  ScreeningStatus,
} from "@/types";

// ── Config ────────────────────────────────────────────────────────────

export const BASE_URL = "http://127.0.0.1:8000";

// ── Error class ───────────────────────────────────────────────────────

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string
  ) {
    super(message);
    this.name = "ApiError";
  }
}

// ── Shared fetch wrapper ──────────────────────────────────────────────

async function apiFetch<T>(
  path: string,
  init?: RequestInit
): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, init);

  if (!res.ok) {
    let code = "UNKNOWN_ERROR";
    let message = `Request failed with status ${res.status}`;
    try {
      const body = await res.json();
      code = body.error ?? code;
      message = body.message ?? message;
    } catch {
      // non-JSON error body — keep defaults
    }
    throw new ApiError(res.status, code, message);
  }

  return res.json() as Promise<T>;
}

// ── Health ────────────────────────────────────────────────────────────

export async function getHealth(): Promise<HealthResponse> {
  return apiFetch<HealthResponse>("/api/health");
}

// ── Dashboard ─────────────────────────────────────────────────────────

export async function getDashboardStats(): Promise<DashboardStats> {
  return apiFetch<DashboardStats>("/api/dashboard/stats");
}

// ── Screenings — list ─────────────────────────────────────────────────

export interface ListScreeningsOptions {
  limit?: number;
  offset?: number;
  status?: ScreeningStatus;
  referable?: boolean;
}

export async function getAllScreenings(
  opts: ListScreeningsOptions = {}
): Promise<ScreeningListItem[]> {
  const params = new URLSearchParams();
  if (opts.limit !== undefined) params.set("limit", String(opts.limit));
  if (opts.offset !== undefined) params.set("offset", String(opts.offset));
  if (opts.status) params.set("status", opts.status);
  if (opts.referable !== undefined)
    params.set("referable", String(opts.referable));

  const qs = params.toString();
  return apiFetch<ScreeningListItem[]>(`/api/screenings${qs ? `?${qs}` : ""}`);
}

export async function getRecentScreenings(): Promise<ScreeningListItem[]> {
  return getAllScreenings({ limit: 10 });
}

export async function getPendingReviews(): Promise<ScreeningListItem[]> {
  return getAllScreenings({ status: "analyzed" });
}

// ── Screenings — single ───────────────────────────────────────────────

export async function getScreening(
  id: string | number
): Promise<FullScreeningReport> {
  return apiFetch<FullScreeningReport>(`/api/screenings/${id}`);
}

// ── Screenings — create (Step 1) ──────────────────────────────────────

export async function createScreening(
  data: CreateScreeningRequest
): Promise<CreateScreeningResponse> {
  const form = new FormData();
  form.append("name", data.name);
  form.append("age", String(data.age));
  form.append("gender", data.gender);
  if (data.patient_id) form.append("patient_id", data.patient_id);
  form.append("file", data.image);

  return apiFetch<CreateScreeningResponse>("/api/screenings", {
    method: "POST",
    body: form,
    // Don't set Content-Type — browser sets it automatically with boundary
  });
}

// ── Screenings — AI analyze (Step 2) ─────────────────────────────────

export async function analyzeScreening(
  id: string | number
): Promise<AIAnalysisResult> {
  return apiFetch<AIAnalysisResult>(`/api/screenings/${id}/analyze`, {
    method: "POST",
  });
}

// ── Screenings — doctor verify (Step 3) ──────────────────────────────

export async function verifyScreening(
  id: string | number,
  payload: VerifyScreeningRequest
): Promise<DoctorVerification> {
  return apiFetch<DoctorVerification>(`/api/screenings/${id}/verify`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
}

// ── Image URL helper ──────────────────────────────────────────────────

/** Returns the absolute URL for a stored fundus image filename. */
export function getImageUrl(filename: string | null): string | null {
  if (!filename) return null;
  if (filename.startsWith("http")) return filename;
  return `${BASE_URL}/uploads/${filename}`;
}
