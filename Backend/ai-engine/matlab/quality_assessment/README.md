# Module: Quality Assessment (`matlab/quality_assessment/`)

**Phase Completed:** Phase 2 (Automated Fundus Image Quality Gatekeeper)  
**Subsystem:** Retino-AI Clinical Quality Assurance  
**Design Philosophy:** Strict classical Computer Vision / Traditional Photometry (zero external AI dependencies).

---

## Purpose & Scope
In rural tele-ophthalmology camps across India, 10% to 25% of fundus acquisitions are clinically ungradable due to patient motion blur, inadequate pupil dilation, camera misalignments, cataract haze, or flash glare.

This module acts as an automated clinical gatekeeper. It audits acquisitions **before** feature extraction or machine learning classification, preventing misleading diagnoses, wasted computational resources, and false positives/negatives.

---

## Implemented Modules & Interfaces

| Function | File | Description |
| :--- | :--- | :--- |
| **`check_blur`** | [`check_blur.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/quality_assessment/check_blur.m) | Evaluates optical focus via variance of the discrete 3x3 Laplacian operator strictly inside the retinal FOV. Rejects out-of-focus or motion-blurred acquisitions. |
| **`check_brightness`** | [`check_brightness.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/quality_assessment/check_brightness.m) | Evaluates mean luminance and Shannon information entropy inside the retinal FOV, ignoring dark background camera borders. Rejects underexposed (dark) or overexposed (flash glare) images. |
| **`check_fov`** | [`check_fov.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/quality_assessment/check_fov.m) | Assesses retinal area coverage fraction and circularity ($4\pi \cdot \text{Area} / \text{Perimeter}^2$) to detect misaligned cameras, severe clipping, or empty captures. Reuses FOV masks from preprocessing. |
| **`assess_image_quality`** | [`assess_image_quality.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/quality_assessment/assess_image_quality.m) | **Unified master quality entry point**. Executes all 3 audits, determines deterministic gradability, and returns actionable clinical rejection reasons. |
| **`visualize_quality_assessment`** | [`visualize_quality_assessment.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/quality_assessment/visualize_quality_assessment.m) | Generates and exports comprehensive 3-panel quality audit cards and master comparison matrices into `outputs/quality_assessment/`. |

---

## Unified Quality Interface: `assess_image_quality(inputImage, cfg)`

### Usage
```matlab
% Recommended: Pass preprocessed struct to directly reuse FOV mask and normalized dimensions
preprocessed = preprocess_fundus('data/raw/aptos/train_images/000c1434d8d7.png');
quality = assess_image_quality(preprocessed);

if quality.is_gradable
    fprintf('Image is gradable! Proceeding to Feature Extraction.\n');
else
    fprintf('Acquisition rejected: %s\n', quality.rejection_reason);
end
```

### Output Structure
```matlab
quality = 
  struct with fields:
       overall_quality: 'excellent'            % 'excellent', 'adequate', 'poor', 'unacceptable'
           is_gradable: true                   % Logical boolean (gatekeeper decision)
            blur_score: 56.28                  % Variance of Laplacian within FOV
      brightness_score: 1.00                   % Photometric exposure index [0.0 to 1.0]
             fov_score: 0.94                   % Coverage and circularity index [0.0 to 1.0]
             blur_pass: true                   % Logical flag
       brightness_pass: true                   % Logical flag
              fov_pass: true                   % Logical flag
      rejection_reason: ''                     % Explainable string listing all failure reasons
     rejection_reasons: {}                     % Cell array of failure strings
              metadata: [1x1 struct]           % Thresholds applied, sizes, and timestamps
     sharpness_details: [1x1 struct]           % Detailed metric breakdown from check_blur
    brightness_details: [1x1 struct]           % Mean luminance, entropy, and verdict
           fov_details: [1x1 struct]           % Area ratio, circularity, and perimeter
```

---

## Configurable Thresholds (`config/training_config.m`)

| Hyperparameter | Value | Description & Selection Rationale |
| :--- | :--- | :--- |
| `cfg.quality.blur_threshold` | **`25.0`** | Minimum variance of Laplacian within FOV. Tested on real datasets: sharp APTOS ($56.28$), IDRiD ($67.99$), and DRIVE ($96.31$) easily pass; mild/moderate Gaussian blur ($\sigma=4-6$) drops to $12.52$, reliably failing. |
| `cfg.quality.brightness_min` | **`35.0`** | Minimum mean luminance within retinal FOV. Real images average $68 - 137$. Underexposed samples drop below $10 - 20$. |
| `cfg.quality.brightness_max` | **`180.0`** | Maximum mean luminance within retinal FOV. Prevents flash glare washed-out acquisitions where blood vessels and macula cannot be delineated. |
| `cfg.quality.min_entropy` | **`4.0`** | Minimum Shannon entropy of pixel intensities within FOV. Ensures adequate dynamic range. |
| `cfg.quality.min_fov_ratio` | **`0.25`** | Minimum retinal area fraction of the image frame ($25\%$). Normal fundus cameras cover $68\% - 75\%$. |
| `cfg.quality.min_circularity` | **`0.35`** | Minimum circularity index ($4\pi A / P^2$) of detected retinal aperture. Rejects clipped slivers and camera alignment failures. |

---

## Visual Verification Artifacts
Saved in [`Backend/ai-engine/outputs/quality_assessment/`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/outputs/quality_assessment):
* `aptos_quality_report.png`: Normal APTOS sample audit card (PASS).
* `idrid_quality_report.png`: Normal IDRiD sample audit card (PASS).
* `drive_quality_report.png`: Normal DRIVE sample audit card (PASS).
* `degraded_blur_report.png`: Gaussian-blurred capture audit card (FAIL - Blur).
* `degraded_underexposed_report.png`: Underexposed capture audit card (FAIL - Underexposure).
* `degraded_overexposed_report.png`: Glare capture audit card (FAIL - Overexposure).
* `degraded_fov_report.png`: Insufficient FOV capture audit card (FAIL - Area ratio).
* `quality_assessment_matrix.png`: Master 6-case comparative overview matrix.
