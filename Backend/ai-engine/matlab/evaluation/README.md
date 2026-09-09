# Module: Evaluation (`matlab/evaluation/`)

**Phase Planned:** Phase 6  
**Subsystem:** Retino-AI Quantitative Model Evaluation & Validation

---

## Purpose & Scope
This module provides rigorous statistical validation and clinical performance metrics for models developed within the AI engine. Diagnostic AI models in healthcare must meet strict benchmarks to ensure patient safety and avoid under-referral of sight-threatening retinopathy.

## Planned Capabilities (Future Development)
* **Confusion Matrix Visualization:** Multi-class confusion matrices mapped to ICDR 0-4 grades.
* **Clinical Diagnostic Metrics:**
  * Sensitivity (Recall) — crucial to minimize false negatives (missed cases of DR).
  * Specificity — minimizing false positive referrals.
  * Positive & Negative Predictive Values (PPV / NPV).
  * Multi-class F1-Scores.
* **Agreement Statistics:** Quadratic Weighted Kappa (QWK) for ordinal severity agreement with ophthalmologist annotations.
* **ROC & Precision-Recall Curves:** Receiver Operating Characteristic analysis for binary referable DR (Grade 0-1 vs Grade 2-4).
* **Exportable Validation Reports:** Automatically generating evaluation summaries for documentation and audit.

## Planned Interfaces (Future Placeholder)
* `evaluate_dr_model.m`: Computes metrics across test predictions and true ground-truth labels.
