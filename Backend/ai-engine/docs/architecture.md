# Retino-AI: Architectural Design & Clinical Context

**Project:** SIH26038 – Explainable AI for Diabetic Retinopathy Screening in Rural India

---

## 1. Problem Statement & Rural Context

Diabetic Retinopathy (DR) is a severe microvascular complication of diabetes leading to irreversible vision impairment if untreated. In rural India:
1. **Ophthalmologist Shortage:** The ratio of ophthalmologists to rural populations is acutely low, resulting in backlogs and delayed diagnoses.
2. **Ungradable Image Ratio:** Field screenings conducted with low-cost portable or non-mydriatic fundus cameras by primary health workers often produce blurry, poorly lit, or off-center images.
3. **The "Black Box" Trust Barrier:** Community doctors and tele-ophthalmologists hesitate to act on autonomous AI predictions unless the system clearly visualizes *why* a particular referral or grade was assigned.

---

## 2. System Architecture

The AI Engine is structured into an eight-phase modular pipeline designed to run on MATLAB:

```
[ Raw Fundus Image ]
         │
         ▼
[ Phase 1: Image Loading & Format Check ]
         │
         ▼
[ Phase 2: Quality Assessment Gatekeeper ] ──(Ungradable)──► [ Re-capture Flag & Advisory ]
         │
         ▼ (Gradable)
[ Phase 3: Preprocessing (Masking, CLAHE, Illumination Correction) ]
         │
         ▼
[ Phase 4: Feature Extraction (Vessel Tree, Lesions, Optic Disc/Macula) ]
         │
         ▼
[ Phase 5: Interpretable Classifier (Random Forest / SVM) ]
         │
         ├──► [ DR Severity: Grade 0 - 4 (ICDR Scale) ]
         │
         ▼
[ Phase 7: Explainability Engine (Visual Evidence & Heatmaps) ]
         │
         ▼
[ Phase 8: Unified Output Artifacts (JSON + Overlay Visualization) ]
         │
         ▼
[ Phase 9: Teammate's FastAPI Backend & Integration Layer ]
```

---

## 3. Clinical Severity Scale (ICDR Standard)

The engine maps all classifications to the International Clinical Diabetic Retinopathy (ICDR) scale:

| Grade | Clinical Description | Pathological Hallmarks | Referral Action |
|---|---|---|---|
| **0** | No Apparent DR | No abnormalities | Routine annual follow-up |
| **1** | Mild NPDR | Microaneurysms only | Follow-up in 6–12 months |
| **2** | Moderate NPDR | Multiple MAs, dot/blot hemorrhages, hard exudates | **Refer to Ophthalmologist** |
| **3** | Severe NPDR | >20 intraretinal hemorrhages in 4 quadrants, venous beading, IRMA | **Urgent Referral** |
| **4** | Proliferative DR (PDR) | Neovascularization, vitreous/preretinal hemorrhage | **Immediate Urgent Intervention** |

---

## 4. Separation of Concerns

* **AI Engine Team (You):** MATLAB algorithm development, image filtering, feature extraction, ML training/tuning, explainability visualization, and unit testing within `Backend/ai-engine`.
* **Backend Team (Teammate):** FastAPI server, API endpoints, user authentication, database models, patient records, and frontend client synchronization within `Backend/api` and `Frontend`.
