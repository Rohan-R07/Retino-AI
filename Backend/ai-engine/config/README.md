# Module: Configuration (`config/`)

**Project:** SIH26038 – Explainable AI for Diabetic Retinopathy Screening in Rural India

---

## Purpose & Scope
Houses centralized configuration files, dataset location registries, and hyperparameter presets for preprocessing, feature extraction, training, and evaluation.

## Configuration Files

1. **`datasets.json`**
   * Machine-agnostic registry for local dataset paths.
   * Keeps local paths out of hardcoded code.
   * Controls which datasets are enabled (`aptos`, `idrid`, `drive`, `messidor2`).

2. **`dataset_config.m`**
   * MATLAB function that parses `datasets.json` or falls back to standard `data/raw/<dataset>` directories.
   * Defines dataset tasks, class labels, and metadata schemas.

3. **`training_config.m`**
   * Central hyperparameter configuration:
     * Fixed random seed (`42`) for reproducibility.
     * Train / Val / Test split ratios (70% / 15% / 15%).
     * Preprocessing flags (FOV crop, CLAHE, illumination normalization).
     * Feature extraction settings (Color, GLCM texture, vessel, lesion).
     * Model candidate settings (Random Forest, Multi-class SVM).
     * Clinical 5-grade ICDR taxonomy.

4. **`config_default.m` & `config.json`**
   * Default engine-level paths and contract specifications shared with backend team.
