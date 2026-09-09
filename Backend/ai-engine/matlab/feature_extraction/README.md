# Module: Feature Extraction (`matlab/feature_extraction/`)

**Phase Completed:** Phase 3 (Prototype Classical Retinal Feature Extraction)  
**Subsystem:** Retino-AI Biomarker Quantification  
**Design Philosophy:** Lightweight, interpretable 22-dimensional feature vector for traditional machine learning classifiers (zero deep learning / zero external AI services).

---

## Purpose & Scope
This module converts each preprocessed fundus image into a compact, deterministic, 22-dimensional numerical feature vector capturing four clinical biomarker groups:
1. **Color statistics** inside the retinal FOV
2. **GLCM Haralick texture metrics** on the green channel
3. **Vascular density & morphology** (validated on DRIVE ground-truth masks)
4. **Pathological lesion evidence** (quantified from IDRiD ground-truth masks)

---

## Implemented Modules & Interfaces

| Function | File | Description |
| :--- | :--- | :--- |
| **`extract_color_features`** | [`extract_color_features.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/feature_extraction/extract_color_features.m) | Extracts 8 color statistics strictly within the retinal FOV: mean RGB, std RGB, green_mean, and green_contrast. |
| **`extract_texture_features`** | [`extract_texture_features.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/feature_extraction/extract_texture_features.m) | Computes 4 Haralick Gray-Level Co-occurrence Matrix (GLCM) texture metrics on the green channel (Contrast, Correlation, Energy, Homogeneity). |
| **`extract_vessel_features`** | [`extract_vessel_features.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/feature_extraction/extract_vessel_features.m) | Quantifies vessel density (vessel area / retinal FOV) and vessel edge density (perimeter / retinal FOV) from DRIVE ground-truth masks. |
| **`extract_lesion_features`** | [`extract_lesion_features.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/feature_extraction/extract_lesion_features.m) | Quantifies area ratios and connected-component lesion counts for microaneurysms, hemorrhages, hard exudates, and soft exudates from IDRiD masks. |
| **`extract_features`** | [`extract_features.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/feature_extraction/extract_features.m) | **Unified master feature extractor**. Combines all modules into a 22-D double vector and structured categories. |
| **`visualize_feature_summary`** | [`visualize_feature_summary.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/feature_extraction/visualize_feature_summary.m) | Generates a 3-panel visual feature summary for a sample IDRiD image in `outputs/features/`. |

---

## Standardized 22-Dimensional Feature Vector

| Index | Feature Label | Category | Description |
| :---: | :--- | :--- | :--- |
| **1** | `mean_red` | Color | Mean red-channel intensity inside retinal FOV |
| **2** | `mean_green` | Color | Mean green-channel intensity inside retinal FOV |
| **3** | `mean_blue` | Color | Mean blue-channel intensity inside retinal FOV |
| **4** | `std_red` | Color | Standard deviation of red channel in FOV |
| **5** | `std_green` | Color | Standard deviation of green channel in FOV |
| **6** | `std_blue` | Color | Standard deviation of blue channel in FOV |
| **7** | `green_mean` | Color | Dedicated green-channel mean intensity |
| **8** | `green_contrast` | Color | Green-channel standard deviation / local contrast |
| **9** | `glcm_contrast` | Texture | GLCM local intensity variation (16 levels, 4 directions) |
| **10** | `glcm_correlation` | Texture | GLCM gray-level linear dependency |
| **11** | `glcm_energy` | Texture | GLCM uniformity and order |
| **12** | `glcm_homogeneity` | Texture | GLCM diagonal concentration |
| **13** | `vessel_density` | Vessel | Fraction of retinal FOV occupied by blood vessels |
| **14** | `vessel_edge_density` | Vessel | Ratio of vessel perimeter pixels to retinal FOV |
| **15** | `microaneurysm_area` | Lesion | Area fraction of microaneurysm foci in FOV |
| **16** | `microaneurysm_count` | Lesion | Connected component count of microaneurysms |
| **17** | `hemorrhage_area` | Lesion | Area fraction of retinal hemorrhages |
| **18** | `hemorrhage_count` | Lesion | Connected component count of hemorrhage patches |
| **19** | `hard_exudate_area` | Lesion | Area fraction of hard lipid exudates |
| **20** | `hard_exudate_count` | Lesion | Connected component count of hard exudates |
| **21** | `soft_exudate_area` | Lesion | Area fraction of cotton-wool soft exudates |
| **22** | `soft_exudate_count` | Lesion | Connected component count of soft exudates |

---

## Dataset Separation & Roles
* **APTOS:** Primary DR severity classification labels (`0 - No DR` to `4 - Proliferative DR`). Color and texture features extracted; vessel/lesion ground truths default to `0.0`.
* **IDRiD:** Disease grading labels and pixel-level lesion evidence (MA, HE, EX, SE masks).
* **DRIVE:** Retinal blood vessel validation masks (`1st_manual`).
* **Messidor-2:** Skipped for prototype phase.

---

## Visual Summary Artifact
* Located at: [`Backend/ai-engine/outputs/features/idrid_feature_summary.png`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/outputs/features/idrid_feature_summary.png)
* Displays:
  1. Standardized retinal image (`IDRiD_01`)
  2. Multi-lesion evidence overlay (Hard Exudates in Yellow, Hemorrhages in Red, Microaneurysms in Cyan)
  3. Extracted 22-D feature vector values
