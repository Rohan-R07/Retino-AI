# Retino-AI Outputs Directory (`outputs/`)

**Project:** SIH26038 – Explainable AI for Diabetic Retinopathy Screening in Rural India

---

## Directory Organization
* **`outputs/preprocessing/`** — Standardized, CLAHE-enhanced, and masked fundus images.
* **`outputs/quality/`** — Image quality audit logs, blur/brightness scores, and ungradable image flags.
* **`outputs/features/`** — Exported tabular feature matrices (CSV / MAT) ready for classifier training.
* **`outputs/models/`** — Serialized trained classifiers (Random Forest `TreeBagger`, SVM `fitcecoc`).
* **`outputs/evaluation/`** — Confusion matrix plots, ROC/PR curves, and clinical performance reports.
* **`outputs/evidence/`** — Visual explainability overlays (color-coded lesion boundaries, vessel maps).
* **`outputs/demo/`** — Session exports and reports generated from the local screening UI.

*Note: All generated output files are transient and excluded from Git tracking via `.gitignore`.*
