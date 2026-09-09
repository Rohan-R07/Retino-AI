# Retino-AI Models Subsystem (`matlab/models/`)

**Project:** SIH26038 – Explainable AI for Diabetic Retinopathy Screening in Rural India

---

## Directory Organization
* **`classification/`** — 5-Class Diabetic Retinopathy severity classification models (ICDR 0 to 4).
* **`vessel_segmentation/`** — Retinal vascular tree segmentation models (trained with DRIVE ground truths).
* **`lesion_detection/`** — Multi-class lesion segmentation (microaneurysms, hemorrhages, exudates using IDRiD annotations).
* **`train/`** — Training orchestration scripts and cross-validation pipelines (`train_classifier.m`, `train_vessel_model.m`, `train_lesion_model.m`).
* **`inference/`** — Model inference wrappers (`predict_dr_grade.m`, `predict_vessels.m`, `predict_lesions.m`).
* **`saved/`** — Destination for saved trained `.mat` model structures (git-ignored).

## Trained Prototype DR Classifier
* **Model Artifact**: `models/saved/dr_random_forest.mat` (and mirrored in `matlab/models/saved/dr_random_forest.mat`)
* **Metadata**: `models/saved/dr_model_metadata.json`
* **Architecture**: Random Forest (100 bagged trees, min leaf size 5)
* **Classes**: 5-class ICDR Diabetic Retinopathy Scale:
  - `0 - No DR`
  - `1 - Mild NPDR`
  - `2 - Moderate NPDR` (Referral threshold)
  - `3 - Severe NPDR` (Referral threshold)
  - `4 - Proliferative DR` (Referral threshold)

## 12 Mask-Free Features (Directly Image-Computable)
For any newly uploaded fundus image without ground-truth lesion or vessel annotations:
1. `mean_red` — Mean red channel intensity in FOV
2. `mean_green` — Mean green channel intensity in FOV
3. `mean_blue` — Mean blue channel intensity in FOV
4. `std_red` — Red channel standard deviation
5. `std_green` — Green channel standard deviation
6. `std_blue` — Blue channel standard deviation
7. `green_mean` — Green channel mean luminance
8. `green_contrast` — Green channel contrast (standard deviation)
9. `glcm_contrast` — GLCM contrast on green channel (16 levels, 4 directions)
10. `glcm_correlation` — GLCM correlation on green channel
11. `glcm_energy` — GLCM angular second moment / energy
12. `glcm_homogeneity` — GLCM inverse difference moment

## Inference Entry Point
* **Function**: `matlab/inference/predict_dr.m`
* **Usage**: `result = predict_dr(imagePath);`
* **Output**: DR grade (0-4), class probabilities (1x5), confidence, quality gate result, 12-D feature vector, referral recommendation (`grade >= 2`).
