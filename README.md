# Retino-AI: Explainable AI for Diabetic Retinopathy Screening in Rural India

[![SIH Problem Statement](https://img.shields.io/badge/SIH-SIH26038-blue.svg)](https://www.sih.gov.in/)
[![Platform](https://img.shields.io/badge/Platform-MATLAB%20%7C%20Python-orange.svg)]()
[![Model](https://img.shields.io/badge/Model-Random%20Forest%20(100%20Trees)-green.svg)]()
[![Accuracy](https://img.shields.io/badge/5--Class%20Accuracy-66.38%25-brightgreen.svg)]()
[![Referable Accuracy](https://img.shields.io/badge/Referral%20Accuracy-82.45%25-brightgreen.svg)]()

> **Problem Statement ID:** SIH26038  
> **Title:** Explainable AI for Diabetic Retinopathy Screening in Rural India  
> **Subsystem:** AI Engine — Classical Computer Vision & Explainable Machine Learning  

---

## 1. Executive Summary

Diabetic Retinopathy (DR) is a primary cause of preventable blindness worldwide, disproportionately impacting rural and semi-urban populations where access to retinal specialists and tertiary ophthalmology clinics is limited. 

**Retino-AI** is designed for rural point-of-care screening:
- **No Costly Cloud GPUs or Black-Box Deep Networks**: Built on robust, deterministic classical computer vision and ensemble machine learning that runs locally on modest field clinic hardware.
- **Strict Quality Gatekeeping**: Automatically inspects images for focus, underexposure, overexposure, and field-of-view (FOV) validity, instantly rejecting ungradable photographs before classification.
- **Mask-Free Clinical Inference**: Does **not** require ground-truth lesion annotations or manual vessel masks. Newly captured patient fundus photographs are evaluated directly from raw pixels.
- **Explainable Clinical Biomarkers**: Translates fundus imagery into 12 measurable color and texture biomarkers (photometric distribution, green-channel microvascular contrast, and Gray-Level Co-occurrence Matrix texture descriptors).

---

## 2. End-to-End Pipeline Architecture

```
                       Raw Retinal Fundus Photograph
                                    │
                                    ▼
       ┌──────────────────────────────────────────────────────────┐
       │             1. Quality Assessment Gatekeeper             │
       │  - Focus / Sharpness Metric (Variance of Laplacian)      │
       │  - Exposure Check (Mean luminance inside retinal FOV)    │
       │  - Retinal Coverage & Circularity Detection              │
       └────────────────────────────┬─────────────────────────────┘
                                    │
                     Is image gradable for diagnosis?
                     ├── NO ──► [UNGRADABLE] Halted with Clinical Advisory
                     └── YES
                                    │
                                    ▼
       ┌──────────────────────────────────────────────────────────┐
       │                2. Fundus Preprocessing                   │
       │  - Retinal Field of View (FOV) auto-crop & margin padding│
       │  - Standardization to 512 x 512 resolution               │
       │  - Green-Channel Isolation (peak hemoglobin contrast)    │
       │  - Illumination Gaussian normalization & CLAHE           │
       └────────────────────────────┬─────────────────────────────┘
                                    │
                                    ▼
       ┌──────────────────────────────────────────────────────────┐
       │              3. Mask-Free Feature Extraction             │
       │  - 8 Photometric Descriptors (Mean & Std RGB, Contrast)  │
       │  - 4 Haralick Texture Metrics (GLCM Contrast, Energy,   │
       │    Correlation, Homogeneity across 4 directions)         │
       └────────────────────────────┬─────────────────────────────┘
                                    │
                                    ▼
       ┌──────────────────────────────────────────────────────────┐
       │             4. Random Forest DR Classifier               │
       │  - 100 Bagged Decision Trees (Min Leaf Size = 5)         │
       │  - Balanced subsample weighting across ICDR Grades 0-4   │
       │  - Multi-class posterior probability distribution (1x5)  │
       └────────────────────────────┬─────────────────────────────┘
                                    │
                                    ▼
       ┌──────────────────────────────────────────────────────────┐
       │             5. Diagnostic & Referral Output              │
       │  - Predicted ICDR Severity Grade (0 to 4)                │
       │  - Screening Confidence Score (0.0 to 1.0)               │
       │  - Referable DR Flag: TRUE if Grade >= 2                 │
       │  - Structured JSON Contract & MATLAB Diagnostic Struct   │
       └──────────────────────────────────────────────────────────┘
```

---

## 3. The 12 Mask-Free Clinical Features

Because incoming patient photographs in rural camps have **zero prior manual segmentations**, the classifier operates exclusively on directly-computable, mask-free biomarkers:

| # | Feature Name | Clinical Rationale | Extraction Domain |
|:---:|:---|:---|:---|
| 1 | `mean_red` | Overall retinal tissue reflectance and background illumination | Retinal FOV |
| 2 | `mean_green` | Blood vessel and retinal hemorrhage absorption | Retinal FOV |
| 3 | `mean_blue` | Optical media clarity / cataract haze scatter | Retinal FOV |
| 4 | `std_red` | Spatial intensity dispersion across choroidal background | Retinal FOV |
| 5 | `std_green` | Microvascular and hemorrhagic contrast variance | Retinal FOV |
| 6 | `std_blue` | Blue channel variance across retinal surface | Retinal FOV |
| 7 | `green_mean` | Dedicated green-channel mean luminance | Retinal FOV |
| 8 | `green_contrast` | Dynamic intensity spread of the green working channel | Retinal FOV |
| 9 | `glcm_contrast` | Local intensity variations in microvascular tissue | Green Channel GLCM (16 levels) |
| 10 | `glcm_correlation`| Linear pixel-pair dependency across neighboring structures | Green Channel GLCM (4 directions) |
| 11 | `glcm_energy` | Uniformity and order of the retinal textural pattern | Green Channel GLCM |
| 12 | `glcm_homogeneity`| Closeness of GLCM element distribution to diagonal | Green Channel GLCM |

---

## 4. Benchmark Performance & Evaluation

The Random Forest model was trained and evaluated on **4,075 clinical retinal images** with a stratified **80% training / 20% held-out test split** (fixed seed `42` for exact reproducibility).

### Overall Metrics on Held-Out Test Set (815 Unseen Images)

| Evaluation Metric | Value | Clinical Significance |
|:---|:---:|:---|
| **5-Class DR Accuracy** | **66.38%** | Multi-class distinction across all 5 stages (chance = 20.0%) |
| **Referable DR Accuracy (`Grade >= 2`)** | **82.45%** | Correct determination of whether patient needs referral |
| **Referable DR Sensitivity** | **76.50%** | Fraction of diseased eyes (`Grade >= 2`) correctly referred (267/349) |
| **Referable DR Specificity** | **86.91%** | Fraction of healthy/mild eyes cleared without unnecessary hospital burden (405/466) |
| **Healthy Eye (Grade 0) Identification** | **92.01%** | 357 out of 388 normal eyes accurately identified |

### 5-Class Confusion Matrix (815 Held-Out Test Images)

```
                     PREDICTED DR GRADE
             0 (No DR)   1 (Mild)   2 (Mod)   3 (Severe)   4 (PDR)    Total   Sensitivity
Actual 0:       357         7         19          3           2        388      92.01%
Actual 1:         9        32         29          5           3         78      41.03%
Actual 2:        23        32        128         22          22        227      56.39%
Actual 3:         5         3         20         15          10         53      28.30%
Actual 4:         7        12         34          7           9         69      13.04%
Total Pred:     401        86        230         52          46        815
```

### Referral Screening Breakdown (`Grade >= 2`)

- **True Positives (TP)**: 267
- **False Negatives (FN)**: 82
- **True Negatives (TN)**: 405
- **False Positives (FP)**: 61
- **Negative Predictive Value (NPV)**: **83.16%** ($\frac{405}{405 + 82}$) — Very high reassurance that a negative screen is safe.

---

## 5. Dataset Separation & Roles

To ensure clinical integrity, datasets are strictly separated by functional roles:

| Dataset | Sample Count | Primary Role in Retino-AI |
|:---|:---:|:---|
| **APTOS 2019 Blindness Detection** | 3,662 | Primary 5-class DR severity classification data |
| **IDRiD Disease Grading** | 413 | Supplementary 5-class DR severity classification data |
| **DRIVE** | 40 | Retinal vascular tree ground-truth validation (NOT used for DR grading) |
| **Messidor-2** | — | Skipped (not required for prototype) |

---

## 6. Repository Organization

```
Retino-AI/
├── Backend/
│   ├── ai-engine/
│   │   ├── config/                     # Pipeline & training configuration
│   │   │   ├── training_config.m       # Hyperparameters, thresholds, feature settings
│   │   │   ├── dataset_config.m        # Dataset paths and loaders config
│   │   │   └── config.json             # Interoperable JSON configuration
│   │   │
│   │   ├── matlab/
│   │   │   ├── preprocessing/          # Stage 1: Preprocessing & FOV isolation
│   │   │   │   ├── load_fundus.m
│   │   │   │   ├── crop_fov.m
│   │   │   │   ├── resize_fundus.m
│   │   │   │   ├── extract_green_channel.m
│   │   │   │   ├── normalize_illumination.m
│   │   │   │   ├── enhance_contrast.m
│   │   │   │   └── preprocess_fundus.m
│   │   │   │
│   │   │   ├── quality_assessment/     # Stage 2: Automated Quality Gatekeeper
│   │   │   │   ├── check_blur.m        # Focus / sharpness evaluation
│   │   │   │   ├── check_brightness.m  # Exposure & illumination evaluation
│   │   │   │   ├── check_fov.m         # Circularity & retinal coverage
│   │   │   │   └── assess_image_quality.m
│   │   │   │
│   │   │   ├── feature_extraction/     # Stage 3: Mask-Free Clinical Biomarkers
│   │   │   │   ├── extract_color_features.m
│   │   │   │   ├── extract_texture_features.m # GLCM Haralick texture descriptors
│   │   │   │   ├── extract_vessel_features.m  # Vascular density metrics
│   │   │   │   ├── extract_lesion_features.m  # Lesion evidence analysis
│   │   │   │   └── extract_features.m
│   │   │   │
│   │   │   ├── models/                 # Stage 4: Model Training & Inference
│   │   │   │   ├── train/
│   │   │   │   │   ├── train_dr_model.m       # Full training pipeline
│   │   │   │   │   └── train_dr_model_runner.py
│   │   │   │   ├── inference/
│   │   │   │   │   └── predict_dr_grade.m
│   │   │   │   └── saved/
│   │   │   │       └── dr_random_forest.mat   # Trained model artifact
│   │   │   │
│   │   │   ├── inference/              # Master Single-Image Inference
│   │   │   │   ├── predict_dr.m        # Master predict_dr() function
│   │   │   │   └── analyze_fundus.m    # Complete explainability pipeline
│   │   │   │
│   │   │   ├── evaluation/             # Metrics, confusion matrix, sensitivity/specificity
│   │   │   ├── setup_paths.m           # Adds folders to MATLAB path
│   │   │   └── startup.m
│   │   │
│   │   ├── models/saved/               # Saved Model Artifacts & Metadata
│   │   │   ├── dr_random_forest.mat    # Native MATLAB tree ensemble (< 500 KB)
│   │   │   ├── dr_model_metadata.json  # Feature ordering & benchmark results
│   │   │   └── held_out_test_samples.json
│   │   │
│   │   ├── outputs/features/           # Feature visualizations & evidence summaries
│   │   │   └── idrid_feature_summary.png
│   │   │
│   │   └── tests/                      # Automated Verification Suites
│   │       ├── test_preprocessing.m
│   │       ├── test_quality_assessment.m
│   │       ├── test_feature_extraction.m
│   │       ├── test_model_inference.m
│   │       ├── run_all_tests.m
│   │       ├── validate_preprocessing.py
│   │       ├── validate_quality_assessment.py
│   │       ├── validate_feature_extraction.py
│   │       └── validate_model_inference.py
│   │
│   └── main.py
├── Frontend/
│   └── index.html
└── README.md
```

---

## 7. Quickstart & Usage

### Running Single-Image Inference in MATLAB

```matlab
% 1. Initialize environment
run('Backend/ai-engine/matlab/setup_paths.m');

% 2. Run end-to-end inference on any new, unannotated fundus photograph
result = predict_dr('sample_fundus.png');

% Inspect results
fprintf('Status: %s\n', result.status);                   % 'GRADABLE' or 'UNGRADABLE'
fprintf('Predicted DR Grade: %d\n', result.predicted_grade); % 0 to 4
fprintf('Screening Confidence: %.1f%%\n', result.confidence * 100);
fprintf('Referral Recommended: %s\n', mat2str(result.referral_recommended));
fprintf('Probabilities: [%s]\n', num2str(result.class_probabilities, '%.3f '));
```

### Running Inference via Validation Runner (CLI)

```bash
python Backend/ai-engine/tests/validate_model_inference.py
```

Output:
```text
======================================================================
       RETINO-AI MODEL INFERENCE TEST SUITE (PHASE 4 PROTOTYPE)       
======================================================================
[LOAD] Loading trained model artifact -> models/saved/dr_random_forest.mat
[MODEL] Model type: random_forest | Classes: [0, 1, 2, 3, 4]
[MODEL] Features (12): ['mean_red', 'mean_green', 'mean_blue', ...]
[MODEL] Training samples: 3260 | Test samples: 815
[MODEL] Test accuracy: 66.38% | Referral accuracy: 82.45%

--- Testing predict_dr on 10 Held-Out Unseen Images (Grades 0-4) ---
  [PASS] Sample 1 (APTOS e4b0df29b96f.png): Actual Grade=0 | Pred Grade=0 | Conf=68.0% | Referral=NO
  [PASS] Sample 2 (APTOS b5a3ca5c0a80.png): Actual Grade=0 | Pred Grade=0 | Conf=85.6% | Referral=NO
  [PASS] Sample 3 (APTOS 0684311afdfc.png): Actual Grade=1 | Pred Grade=1 | Conf=47.7% | Referral=NO
  ...
--- Testing Quality Gate on Intentionally Poor Quality Image ---
  [PASS] Quality gate properly tripped on dark image: status=UNGRADABLE

TEST RESULT: 11 / 11 Tests Passed
>>> ALL MODEL INFERENCE AND QUALITY GATE VERIFICATIONS PASSED!
```

---

## 8. License & Attribution

- **Project:** SIH26038 — Smart India Hackathon
- **Datasets:** APTOS 2019 Blindness Detection, Indian Diabetic Retinopathy Image Dataset (IDRiD), Digital Retinal Images for Vessel Extraction (DRIVE).
