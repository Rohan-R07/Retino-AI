# Retino-AI Demo UI (`demo/matlab_app/`)

**Project:** SIH26038 – Explainable AI for Diabetic Retinopathy Screening in Rural India  
**Target:** Local Standalone MATLAB App Designer Interface

---

## Purpose & Scope
This directory houses the temporary local demonstration and screening interface built natively in MATLAB App Designer. It allows tele-screening operators and health camp workers to test the AI engine locally without running web servers or external dependencies.

## Planned Workflow
```
[ Upload / Select Fundus Image ]
             │
             ▼
     [ Run AI Analysis ]
             │
   ┌─────────┴─────────┐
   ▼                   ▼
[ Original Image ]  [ Processed Image ]
   │                   │
   └─────────┬─────────┘
             ▼
[ Predicted DR Severity (ICDR Grade 0 to 4) ]
             ▼
[ Model Confidence & Referral Indicator ]
             ▼
[ Visual Evidence Overlay & Clinical Explanation ]
```

## Running the UI
From the MATLAB Command Window:
```matlab
launch_demo_ui
```

*Note: In accordance with project instructions, no external React, Next.js, or web frontends are created here.*
