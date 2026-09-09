# Retino-AI: AI Engine Workspace

**Project:** SIH26038 – Explainable AI for Diabetic Retinopathy Screening in Rural India  
**Subsystem:** Image Processing, Computer Vision & Machine Learning (AI Engine)

---

## 1. Overview & Objectives

Diabetic Retinopathy (DR) is one of the leading causes of preventable blindness worldwide, particularly affecting rural and underserved populations where ophthalmologists and diagnostic infrastructure are scarce. 

This AI Engine workspace hosts the core image processing, medical image quality assurance, feature extraction, explainable machine learning, and inference pipelines. 

### Division of Responsibilities
* **AI Engine (This Workspace):** Responsible exclusively for MATLAB-based medical image processing, quality verification, clinical feature extraction, ML classification (e.g., Random Forest, SVM), visual explainability generation, and single-image inference.
* **Backend API & Platform (Teammate Subsystem):** Separately handles FastAPI endpoints, asynchronous processing queues, JSON contracts, database storage, authentication, and frontend integration.

---

## 2. Technology Stack & Prerequisites

* **Primary Platform:** MATLAB (R2022b or later recommended)
* **Core MATLAB Toolboxes:**
  * Image Processing Toolbox (Preprocessing, CLAHE, morphological operations)
  * Computer Vision Toolbox (Feature representation, visual analysis)
  * Statistics and Machine Learning Toolbox (Classifiers, ensemble methods, cross-validation)
  * Medical Imaging Toolbox (Fundus image formats, filtering, specialized medical operations)
  * *Deep Learning Toolbox* (Optional future dependency)
* **Secondary / Interoperability:** Python (for lightweight integration utilities and future FastAPI bridges)

---

## 3. Directory Structure

```
ai-engine/
│
├── matlab/
│   ├── preprocessing/          # Image resizing, normalization, CLAHE, denoising
│   ├── quality_assessment/      # Quality verification (focus, illumination, field-of-view)
│   ├── feature_extraction/      # Microaneurysms, hemorrhages, exudates, vessel segmentation
│   ├── models/                  # Machine learning models (Random Forest, SVM, training scripts)
│   ├── explainability/          # Visual evidence, heatmaps, lesion highlight overlays
│   ├── evaluation/              # Validation metrics, ROC-AUC, confusion matrices
│   ├── inference/               # Single-image end-to-end inference pipeline
│   ├── setup_paths.m            # Script to register all folders onto MATLAB search path
│   └── startup.m                # Automated environment initialization
│
├── python/
│   ├── utils/                   # Shared lightweight helper scripts
│   ├── integration/             # Bridges for MATLAB Engine / FastAPI IPC
│   └── requirements.txt         # Minimal Python dependencies (no external AI APIs)
│
├── config/
│   ├── config_default.m         # Default MATLAB configuration struct
│   ├── config.json              # Interoperable JSON configuration
│   └── README.md
│
├── tests/
│   ├── verify_environment.m     # Environment and toolbox verification suite
│   ├── run_all_tests.m          # Master test runner
│   └── README.md
│
├── sample_data/                 # Minimal local sample images for unit testing (not tracked)
├── outputs/                     # Generated visual outputs, heatmaps, reports (not tracked)
├── docs/                        # Clinical context, architecture diagrams, notes
├── .gitignore                   # Ignores autosaves, large models, outputs, datasets
└── README.md                    # Project workspace documentation
```

---

## 4. Development Phases

This workspace is architected to support progressive, structured development across the following planned phases:

1. **Phase 1 → Image Loading:** Robust reading of raw retinal fundus photographs (JPEG, PNG, TIFF, DICOM) and metadata parsing.
2. **Phase 2 → Image Quality Assessment:** Automated screening of image quality (illumination, blur/focus, field of view) to reject ungradable images before inference.
3. **Phase 3 → Image Preprocessing:** Retinal mask generation, green-channel extraction, contrast-limited adaptive histogram equalization (CLAHE), and illumination correction.
4. **Phase 4 → Feature Extraction:** Vessel segmentation, optic disc localization, lesion detection (microaneurysms, hemorrhages, hard/soft exudates).
5. **Phase 5 → ML Training:** Training interpretable machine learning models (e.g., Random Forest, SVM) mapped to ICDR 5-stage DR severity scale.
6. **Phase 6 → Evaluation:** Quantitative validation using Sensitivity, Specificity, F1-score, Quadratic Weighted Kappa, and Confusion Matrices.
7. **Phase 7 → Explainability:** Visual localization of clinical findings (bounding boxes, heatmaps, segmented lesions) for rural health workers and clinicians.
8. **Phase 8 → Inference Pipeline:** Unified `analyze_fundus(imagePath)` interface generating structured findings and visual overlays.
9. **Phase 9 → FastAPI Integration:** Interfacing inference outputs with the teammate's web API layer.

---

## 5. Benchmark Performance & Evaluation (Full Dataset Retrained)

The Random Forest model is trained on **4,075 clinical retinal images** (3,662 APTOS + 413 IDRiD) with an 80% train / 20% stratified held-out test split (815 test images):

* **5-Class DR Accuracy**: **66.38%** (Random chance = 20.0%)
* **Referable DR Screening Accuracy (`Grade >= 2`)**: **82.45%**
* **Referable DR Sensitivity**: **76.50%** (267 / 349)
* **Referable DR Specificity**: **86.91%** (405 / 466)
* **Normal Eye (Grade 0) Recall**: **92.01%** (357 / 388)

### 5-Class Confusion Matrix (815 Held-Out Test Images)
```text
                     PREDICTED DR GRADE
             0 (No DR)   1 (Mild)   2 (Mod)   3 (Severe)   4 (PDR)    Total   Sensitivity
Actual 0:       357         7         19          3           2        388      92.01%
Actual 1:         9        32         29          5           3         78      41.03%
Actual 2:        23        32        128         22          22        227      56.39%
Actual 3:         5         3         20         15          10         53      28.30%
Actual 4:         7        12         34          7           9         69      13.04%
Total Pred:     401        86        230         52          46        815
```

---

## 6. Getting Started

### Running Single-Image Inference in MATLAB
```matlab
% 1. Add paths
run('Backend/ai-engine/matlab/setup_paths.m');

% 2. Predict DR grade on any unannotated fundus photograph
result = predict_dr('sample_fundus.png');

disp(result);
```

### Running Test Verification
```bash
python Backend/ai-engine/tests/validate_model_inference.py
```
