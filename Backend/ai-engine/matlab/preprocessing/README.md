# Module: Preprocessing (`matlab/preprocessing/`)

**Phase Completed:** Phase 1 (Actual Fundus Image Preprocessing)  
**Subsystem:** Retino-AI Classical Preprocessing Pipeline  
**Design Philosophy:** Strict classical Computer Vision / Traditional Image Processing (zero external AI dependencies).

---

## Purpose & Scope
This module prepares raw retinal fundus images for quality verification, explainable feature extraction, and traditional machine learning classification. In rural Indian screening settings, raw images frequently suffer from uneven lighting, poor pupil dilation, camera sensor noise, and diverse resolutions.

The pipeline isolates the circular retinal aperture, standardizes resolution, balances illumination across the retina, and enhances fine vascular/lesion details without degrading microaneurysms or hard exudates.

---

## Implemented Modules & Interfaces

| Function | File | Description |
| :--- | :--- | :--- |
| **`load_fundus`** | [`load_fundus.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/preprocessing/load_fundus.m) | Loads PNG, JPG, TIF, DICOM; standardizes to 3-channel `uint8` RGB; strips alpha channels; converts grayscale to RGB. |
| **`crop_fov`** | [`crop_fov.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/preprocessing/crop_fov.m) | Detects circular retinal field-of-view (FOV) via adaptive Otsu cutoff (`graythresh * 0.15`), morphological closing & fill, largest connected component detection, with safety padding margin (`fov_padding=10`). |
| **`resize_fundus`** | [`resize_fundus.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/preprocessing/resize_fundus.m) | Standardizes image dimensions to prototype `[512, 512]` using bicubic interpolation; dynamically inherits target size from `training_config()`. |
| **`extract_green_channel`** | [`extract_green_channel.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/preprocessing/extract_green_channel.m) | Isolates green color plane (channel 2) where contrast between retinal lesions (microaneurysms, hemorrhages, blood vessels) and the retinal background is highest. |
| **`normalize_illumination`** | [`normalize_illumination.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/preprocessing/normalize_illumination.m) | Corrects uneven brightness via Graham background subtraction (`I - bg + mean`). Suppresses boundary halo artifacts by filling background with retinal mean before Gaussian filtering ($\sigma = 30$). |
| **`enhance_contrast`** | [`enhance_contrast.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/preprocessing/enhance_contrast.m) | Contrast-Limited Adaptive Histogram Equalization (CLAHE) in CIE $L^*a^*b^*$ color space to preserve color balance, with configurable clip limit (0.02) and Rayleigh distribution. |
| **`denoise_fundus`** | [`denoise_fundus.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/preprocessing/denoise_fundus.m) | Lightweight 3x3 median filtering preserving fine pathological boundaries (microaneurysms <10px) while removing sensor grain. |
| **`preprocess_fundus`** | [`preprocess_fundus.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/preprocessing/preprocess_fundus.m) | **Unified master entry point**. Executes all stages in sequence and returns a structured output object. |
| **`visualize_preprocessing_stages`** | [`visualize_preprocessing_stages.m`](file:///c:/Users/Rohan%20R/Documents/Hackathons/Retino%20AI/Backend/ai-engine/matlab/preprocessing/visualize_preprocessing_stages.m) | Generates and exports multi-stage visual comparison montages for APTOS, IDRiD, and DRIVE to `outputs/preprocessing/`. |

---

## Unified Entry Point: `preprocess_fundus(image, cfg)`

### Usage
```matlab
% From image file path:
processed = preprocess_fundus('data/raw/aptos/train_images/000c1434d8d7.png');

% From in-memory matrix with custom config:
cfg = training_config();
cfg.preprocessing.clahe_clip_limit = 0.03;
processed = preprocess_fundus(rawImgMatrix, cfg.preprocessing);
```

### Returned Structure
* `.original`: Raw standardized RGB image `[H x W x 3]` uint8.
* `.cropped`: Tightly cropped retinal image with safety padding.
* `.resized`: Standardized prototype image `[512 x 512 x 3]` uint8.
* `.green_channel`: Extracted green plane `[512 x 512]` uint8.
* `.normalized`: Illumination-normalized RGB image `[512 x 512 x 3]` uint8.
* `.enhanced`: Contrast-enhanced (CLAHE) RGB image `[512 x 512 x 3]` uint8.
* `.enhanced_green`: Contrast-enhanced green channel `[512 x 512]` uint8.
* `.denoised`: Edge-preserving denoised green channel `[512 x 512]` uint8.
* `.fov_mask`: Binary retinal field-of-view mask `[512 x 512]` logical.
* `.metadata`: Load details, original dimensions, crop bounding box, and applied configuration.

---

## Configurable Hyperparameters (`config/training_config.m`)

```matlab
cfg.preprocessing.target_size             = [512, 512];    % Standardized prototype size
cfg.preprocessing.enable_fov_crop         = true;          % Retinal aperture isolation
cfg.preprocessing.fov_padding             = 10;            % Safety margin around detected FOV
cfg.preprocessing.enable_illumination_norm= true;          % Graham background subtraction
cfg.preprocessing.illumination_method     = 'subtraction'; % 'subtraction' or 'division'
cfg.preprocessing.illumination_sigma      = 30;            % Background estimation blur std
cfg.preprocessing.enable_clahe            = true;          % CLAHE contrast enhancement
cfg.preprocessing.clahe_clip_limit        = 0.02;          % CLAHE clip limit (0.01 - 0.05)
cfg.preprocessing.clahe_distribution      = 'rayleigh';    % 'rayleigh', 'uniform', 'exponential'
cfg.preprocessing.clahe_num_tiles         = [8, 8];        % Contextual grid tiles
cfg.preprocessing.enable_denoising        = true;          % Lightweight spatial filter
cfg.preprocessing.denoise_method          = 'median';      % 'median' or 'gaussian'
cfg.preprocessing.denoise_kernel          = [3, 3];        % Filter window size
```

---

## Visual Verification Artifacts
Generated visual comparison stages (`Original → FOV Crop → Resized → Green Channel → Normalized → Enhanced`) are stored in:
`Backend/ai-engine/outputs/preprocessing/`
* `aptos_stages.png`: High-resolution visual stages for APTOS 2019 (PNG).
* `idrid_stages.png`: High-resolution visual stages for IDRiD (JPG).
* `drive_stages.png`: High-resolution visual stages for DRIVE (TIF).
