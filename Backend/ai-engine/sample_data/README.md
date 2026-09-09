# Sample Data Directory (`sample_data/`)

## Purpose & Scope
This directory is reserved for small local test retinal fundus images used strictly for development and smoke-testing the pipeline (Phase 1–8).

## Guidelines
* **No Automatic Dataset Downloads:** In accordance with project requirements, large medical image datasets (e.g., EyePACS, Messidor, IDRiD, DDR, APTOS 2019) must NOT be downloaded or committed to version control.
* **Excluded from Git:** The contents of this directory (images) are excluded via `.gitignore` to prevent repo bloat and protect clinical data privacy.
* **Supported Formats:** `.jpg`, `.png`, `.tif`, `.tiff`, `.dcm` (DICOM).
