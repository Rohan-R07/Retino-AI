# Retino-AI Data Directory (`data/`)

**Project:** SIH26038 – Explainable AI for Diabetic Retinopathy Screening in Rural India

---

## Structure & Data Flow

```
data/
├── raw/                  # UNTOUCHED original datasets (downloaded locally by user)
│   ├── aptos/            # APTOS 2019 Blindness Detection (train.csv, train_images/)
│   ├── idrid/            # IDRiD (DR grading labels, original images, pixel lesion masks)
│   ├── drive/            # DRIVE (40 fundus images, manual vessel masks, FOV masks)
│   └── messidor2/        # Messidor-2 (Evaluation & generalization images, labels)
│
├── processed/            # GENERATED preprocessed artifacts (CLAHE, green channel, masks)
│   ├── aptos/
│   ├── idrid/
│   ├── drive/
│   └── messidor2/
│
└── splits/               # GENERATED train / validation / test partition tables (CSV/MAT)
    ├── aptos/
    ├── idrid/
    ├── drive/
    └── messidor2/
```

## Critical Rules
1. **Raw Data Immutability:** Files inside `data/raw/` must NEVER be modified or overwritten by preprocessing pipelines.
2. **Git Tracking:** All dataset images, label CSVs, and preprocessed matrices are excluded from Git via `.gitignore`.
3. **Configuration:** Dataset local roots are configured in `config/datasets.json`.
