# Module: Tests (`tests/`)

## Purpose & Scope
This directory contains unit tests, integration tests, and environment verification scripts for the AI Engine.

## Files
* `verify_environment.m`: Inspects installed MATLAB toolboxes (Image Processing, Computer Vision, Statistics & ML, Medical Imaging, Deep Learning) and validates that all project subdirectories exist.
* `verify_datasets.m`: Audits local availability, file integrity, and ground-truth label bindings for APTOS, IDRiD, and DRIVE datasets.
* `test_preprocessing.m`: Unit and integration test suite verifying the 7-stage classical preprocessing pipeline across real fundus images in PNG (APTOS), JPG (IDRiD), and TIF (DRIVE) formats.
* `test_quality_assessment.m`: Verifies image quality gatekeeper audits (blur, exposure, FOV coverage) on normal and degraded captures.
* `validate_preprocessing.py`: Standalone cross-validation and visual verification generator for automated CI/headless execution.
* `validate_quality_assessment.py`: Standalone quality assessment validator and visual audit card generator.
* `run_all_tests.m`: Master entry point to execute the complete health, dataset, preprocessing, and quality test suite.

## Running Tests
In the MATLAB Command Window:
```matlab
% Run complete master test suite
results = run_all_tests();

% Or run specific test modules
prepResults = test_preprocessing();
qaResults = test_quality_assessment();
```

Via Command Line / Python:
```bash
python tests/validate_preprocessing.py
python tests/validate_quality_assessment.py
```
