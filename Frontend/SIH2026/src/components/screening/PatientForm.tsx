import { useState, type FormEvent } from "react";

export interface PatientFormData {
  name: string;
  age: number;
  gender: "Male" | "Female" | "Other";
  patient_id?: string;
}

interface PatientFormProps {
  onSubmit: (data: PatientFormData) => void;
  isLoading?: boolean;
}

/**
 * Step 1 of the screening workflow — collect basic patient information.
 * Fields align with POST /api/screenings multipart form field names.
 */
export function PatientForm({ onSubmit, isLoading = false }: PatientFormProps) {
  const [name, setName] = useState("");
  const [patientId, setPatientId] = useState("");
  const [age, setAge] = useState("");
  const [gender, setGender] = useState<"Male" | "Female" | "Other">("Male");

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !age) return;
    onSubmit({
      name: name.trim(),
      age: parseInt(age, 10),
      gender,
      patient_id: patientId.trim() || undefined,
    });
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      {/* Patient Name */}
      <div className="space-y-2">
        <label
          htmlFor="patient-name"
          className="block text-base font-medium text-foreground"
        >
          Patient Name <span className="text-red-500">*</span>
        </label>
        <p className="text-sm text-muted-foreground">
          Enter the patient's full name.
        </p>
        <input
          id="patient-name"
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="e.g., John Doe"
          required
          className="w-full rounded-lg border border-input bg-white px-4 py-3 text-base text-foreground placeholder:text-muted-foreground focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
        />
      </div>

      {/* Patient ID (optional) */}
      <div className="space-y-2">
        <label
          htmlFor="patient-id"
          className="block text-base font-medium text-foreground"
        >
          Patient ID{" "}
          <span className="text-sm font-normal text-muted-foreground">
            (optional — auto-generated if blank)
          </span>
        </label>
        <input
          id="patient-id"
          type="text"
          value={patientId}
          onChange={(e) => setPatientId(e.target.value)}
          placeholder="e.g., PAT-001"
          className="w-full rounded-lg border border-input bg-white px-4 py-3 text-base text-foreground placeholder:text-muted-foreground focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
        />
      </div>

      {/* Age */}
      <div className="space-y-2">
        <label
          htmlFor="patient-age"
          className="block text-base font-medium text-foreground"
        >
          Age <span className="text-red-500">*</span>
        </label>
        <p className="text-sm text-muted-foreground">
          Enter the patient's age in years (0–150).
        </p>
        <input
          id="patient-age"
          type="number"
          min="0"
          max="150"
          value={age}
          onChange={(e) => setAge(e.target.value)}
          placeholder="e.g., 55"
          required
          className="w-full rounded-lg border border-input bg-white px-4 py-3 text-base text-foreground placeholder:text-muted-foreground focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
        />
      </div>

      {/* Gender */}
      <div className="space-y-2">
        <label
          htmlFor="patient-gender"
          className="block text-base font-medium text-foreground"
        >
          Gender <span className="text-red-500">*</span>
        </label>
        <select
          id="patient-gender"
          value={gender}
          onChange={(e) =>
            setGender(e.target.value as "Male" | "Female" | "Other")
          }
          className="w-full rounded-lg border border-input bg-white px-4 py-3 text-base text-foreground focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
        >
          <option value="Male">Male</option>
          <option value="Female">Female</option>
          <option value="Other">Other</option>
        </select>
      </div>

      {/* Submit */}
      <button
        type="submit"
        disabled={isLoading || !name.trim() || !age}
        className="w-full rounded-lg bg-primary px-6 py-3.5 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-50 disabled:cursor-not-allowed sm:w-auto"
      >
        {isLoading ? "Please wait..." : "Continue"}
      </button>
    </form>
  );
}
