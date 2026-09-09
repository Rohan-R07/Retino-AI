"""
Retino-AI: Full Dataset Random Forest Retraining Runner
Trains on all available APTOS 2019 images (+ IDRiD Disease Grading).
Evaluates on a stratified held-out test set and exports dr_random_forest.mat.
"""
import os
import sys
import time
import json
from concurrent.futures import ThreadPoolExecutor
import numpy as np
import pandas as pd
from PIL import Image
from sklearn.ensemble import RandomForestClassifier
from scipy import io as spio

print('=================================================================')
print('  RETINO-AI: RANDOM FOREST RETRAINING (FULL APTOS DATASET)       ')
print('=================================================================')

this_dir = os.path.dirname(os.path.abspath(__file__))
matlab_dir = os.path.dirname(os.path.dirname(this_dir))
root_dir = os.path.dirname(matlab_dir)

aptos_csv = os.path.join(root_dir, 'data', 'raw', 'aptos', 'train.csv')
aptos_img_dir = os.path.join(root_dir, 'data', 'raw', 'aptos', 'train_images')
idrid_csv = os.path.join(root_dir, 'data', 'raw', 'idrid', 'Disease Grading',
                         '2. Groundtruths', 'a. IDRiD_Disease Grading_Training Labels.csv')
idrid_img_dir = os.path.join(root_dir, 'data', 'raw', 'idrid', 'Disease Grading',
                            '1. Original Images', 'a. Training Set')

feature_names = [
    'mean_red', 'mean_green', 'mean_blue',
    'std_red', 'std_green', 'std_blue',
    'green_mean', 'green_contrast',
    'glcm_contrast', 'glcm_correlation',
    'glcm_energy', 'glcm_homogeneity'
]

class_labels = [
    '0 - No DR',
    '1 - Mild NPDR',
    '2 - Moderate NPDR',
    '3 - Severe NPDR',
    '4 - Proliferative DR'
]

def extract_12_features(img_path):
    try:
        img = Image.open(img_path).convert('RGB')
        img_arr = np.array(img.resize((512, 512)), dtype=np.uint8)

        # Retinal FOV mask
        gray = (0.2989 * img_arr[:, :, 0] + 0.5870 * img_arr[:, :, 1] + 0.1140 * img_arr[:, :, 2]).astype(np.uint8)
        fov_mask = gray > 10
        if not np.any(fov_mask):
            fov_mask = np.ones(gray.shape, dtype=bool)

        r_ch = img_arr[:, :, 0][fov_mask].astype(np.float64)
        g_ch = img_arr[:, :, 1][fov_mask].astype(np.float64)
        b_ch = img_arr[:, :, 2][fov_mask].astype(np.float64)

        mean_r = float(np.mean(r_ch)) if len(r_ch) > 0 else 0.0
        mean_g = float(np.mean(g_ch)) if len(g_ch) > 0 else 0.0
        mean_b = float(np.mean(b_ch)) if len(b_ch) > 0 else 0.0
        std_r = float(np.std(r_ch)) if len(r_ch) > 0 else 0.0
        std_g = float(np.std(g_ch)) if len(g_ch) > 0 else 0.0
        std_b = float(np.std(b_ch)) if len(b_ch) > 0 else 0.0
        green_mean = mean_g
        green_contrast = std_g

        # GLCM texture features on green channel
        green_plane = img_arr[:, :, 1].copy()
        green_plane[~fov_mask] = 0
        g_sub = green_plane[::4, ::4]
        g_quant = np.clip((g_sub.astype(np.float64) / 256.0 * 16).astype(np.int32), 0, 15)

        offsets = [(0, 1), (-1, 1), (-1, 0), (-1, -1)]
        glcm_accum = np.zeros((16, 16), dtype=np.float64)
        H, W = g_quant.shape
        for dy, dx in offsets:
            y1 = max(0, -dy)
            y2 = min(H, H - dy)
            x1 = max(0, -dx)
            x2 = min(W, W - dx)
            src = g_quant[y1:y2, x1:x2].ravel()
            dst = g_quant[y1+dy:y2+dy, x1+dx:x2+dx].ravel()
            counts = np.bincount(src * 16 + dst, minlength=256).reshape((16, 16))
            glcm_accum += counts
            glcm_accum += counts.T

        tot = np.sum(glcm_accum)
        if tot > 0:
            glcm_accum /= tot

        i_idx, j_idx = np.indices((16, 16))
        diff = i_idx - j_idx
        glcm_contrast = float(np.sum(glcm_accum * (diff ** 2)))
        glcm_homogeneity = float(np.sum(glcm_accum / (1.0 + np.abs(diff))))
        glcm_energy = float(np.sum(glcm_accum ** 2))
        mu_i = np.sum(i_idx * glcm_accum)
        mu_j = np.sum(j_idx * glcm_accum)
        var_i = np.sum(glcm_accum * (i_idx - mu_i) ** 2)
        var_j = np.sum(glcm_accum * (j_idx - mu_j) ** 2)
        if var_i * var_j > 1e-10:
            glcm_correlation = float(np.sum(glcm_accum * (i_idx - mu_i) * (j_idx - mu_j)) / np.sqrt(var_i * var_j))
        else:
            glcm_correlation = 1.0

        return [
            mean_r, mean_g, mean_b,
            std_r, std_g, std_b,
            green_mean, green_contrast,
            glcm_contrast, glcm_correlation,
            glcm_energy, glcm_homogeneity
        ]
    except Exception as e:
        return [0.0] * 12

# 1. Load All Available APTOS Images
samples = []
df_aptos = pd.read_csv(aptos_csv)
print(f'[DATA] APTOS CSV loaded: {len(df_aptos)} rows')
for _, row in df_aptos.iterrows():
    id_code = str(row['id_code'])
    p = os.path.join(aptos_img_dir, id_code + '.png')
    if os.path.exists(p):
        samples.append({'path': p, 'grade': int(row['diagnosis']), 'dataset': 'APTOS'})

# Load IDRiD Images
if os.path.exists(idrid_csv) and os.path.exists(idrid_img_dir):
    df_idrid = pd.read_csv(idrid_csv)
    img_col = df_idrid.columns[0]
    grade_col = [c for c in df_idrid.columns if 'retinopathy' in c.lower()][0]
    for _, row in df_idrid.iterrows():
        p = os.path.join(idrid_img_dir, str(row[img_col]) + '.jpg')
        if os.path.exists(p):
            samples.append({'path': p, 'grade': int(row[grade_col]), 'dataset': 'IDRiD'})

df_samples = pd.DataFrame(samples)
print(f'[DATA] Total available dataset images: {len(df_samples)}')
print('[DATA] Class distribution across full dataset:')
print(df_samples['grade'].value_counts().sort_index())

# 2. Stratified 80% Train / 20% Held-Out Test Split
train_list = []
test_list = []
np.random.seed(42)
for g in range(5):
    sub = df_samples[df_samples['grade'] == g].sample(frac=1.0, random_state=42)
    n_test = int(round(0.20 * len(sub)))
    test_list.append(sub.iloc[:n_test])
    train_list.append(sub.iloc[n_test:])

df_train = pd.concat(train_list, ignore_index=True)
df_test = pd.concat(test_list, ignore_index=True)

print(f'\n[SPLIT] Training pool: {len(df_train)} images')
print(df_train['grade'].value_counts().sort_index())
print(f'[SPLIT] Held-out test pool: {len(df_test)} images')
print(df_test['grade'].value_counts().sort_index())

# 3. Fast Multithreaded Feature Extraction
t0 = time.time()
print(f'\n[PIPELINE] Extracting 12 mask-free features for {len(df_train)} training images (8 threads)...')
with ThreadPoolExecutor(max_workers=8) as ex:
    train_feats = list(ex.map(extract_12_features, df_train['path']))
X_train = np.array(train_feats, dtype=np.float64)
y_train = df_train['grade'].values

print(f'[PIPELINE] Extracting 12 mask-free features for {len(df_test)} test images (8 threads)...')
with ThreadPoolExecutor(max_workers=8) as ex:
    test_feats = list(ex.map(extract_12_features, df_test['path']))
X_test = np.array(test_feats, dtype=np.float64)
y_test = df_test['grade'].values
print(f'[PIPELINE] All features extracted in {time.time() - t0:.2f} s')

# 4. Fit Random Forest Classifier (100 Trees, balanced subsample)
print('\n[TRAIN] Training Random Forest classifier (100 trees, min_samples_leaf=5, balanced)...')
rf = RandomForestClassifier(
    n_estimators=100,
    min_samples_leaf=5,
    class_weight='balanced_subsample',
    random_state=42,
    n_jobs=-1
)
rf.fit(X_train, y_train)

# 5. Evaluate on Stratified Held-Out Test Set
y_pred = rf.predict(X_test)
acc = float(np.mean(y_pred == y_test))

# 5x5 Confusion Matrix
conf_mat = np.zeros((5, 5), dtype=int)
for a, p in zip(y_test, y_pred):
    conf_mat[a, p] += 1

# Referable DR Metrics (Threshold: Grade >= 2)
# Positive = Referable (Grade >= 2)
# Negative = Non-Referable (Grade 0 or 1)
ref_actual = (y_test >= 2)
ref_pred = (y_pred >= 2)

tp = int(np.sum(ref_actual & ref_pred))
fn = int(np.sum(ref_actual & ~ref_pred))
tn = int(np.sum(~ref_actual & ~ref_pred))
fp = int(np.sum(~ref_actual & ref_pred))

sens = tp / (tp + fn) if (tp + fn) > 0 else 0.0
spec = tn / (tn + fp) if (tn + fp) > 0 else 0.0
ref_acc = (tp + tn) / (tp + tn + fp + fn)

print('\n=================================================================')
print('  RETRAINED RANDOM FOREST EVALUATION (HELD-OUT TEST SET)         ')
print('=================================================================')
print(f'  Held-Out Test Size: {len(y_test)} images')
print(f'  5-Class DR Accuracy: {acc * 100:.2f}%')
print(f'  Referable DR Accuracy (Grade >= 2): {ref_acc * 100:.2f}%')
print(f'  Referable DR Sensitivity: {sens * 100:.2f}% (TP={tp}, FN={fn})')
print(f'  Referable DR Specificity: {spec * 100:.2f}% (TN={tn}, FP={fp})')
print('\n  Confusion Matrix (Rows: Actual 0-4, Cols: Predicted 0-4):')
print(conf_mat)
print('\n  Per-Class Recall / Sensitivity:')
for g in range(5):
    tot = np.sum(y_test == g)
    corr = conf_mat[g, g]
    s = (corr / tot * 100) if tot > 0 else 0.0
    print(f'    Grade {g} ({class_labels[g]}): {s:.1f}% ({corr}/{tot})')
print('=================================================================\n')

# 6. Convert Decision Trees to MATLAB struct format
mat_trees = []
for estimator in rf.estimators_:
    tree = estimator.tree_
    vals = tree.value[:, 0, :]
    mat_trees.append({
        'children_left': tree.children_left.astype(np.int32),
        'children_right': tree.children_right.astype(np.int32),
        'feature': tree.feature.astype(np.int32),
        'threshold': tree.threshold.astype(np.float64),
        'value': vals.astype(np.float64)
    })

model_struct = {
    'type': 'random_forest',
    'feature_names': np.array(feature_names, dtype=object),
    'num_features': 12,
    'classes': np.array([0, 1, 2, 3, 4], dtype=np.int32),
    'class_labels': np.array(class_labels, dtype=object),
    'num_classes': 5,
    'is_trained': True,
    'trained': True,
    'training_samples': len(df_train),
    'test_samples': len(df_test),
    'accuracy': acc,
    'referral_accuracy': ref_acc,
    'referral_sensitivity': sens,
    'referral_specificity': spec,
    'confusion_matrix': conf_mat,
    'trees': mat_trees
}

metadata_struct = {
    'feature_names': np.array(feature_names, dtype=object),
    'feature_ordering': np.arange(1, 13, dtype=np.int32),
    'class_labels': np.array(class_labels, dtype=object),
    'train_count': len(df_train),
    'test_count': len(df_test),
    'accuracy': acc,
    'referral_accuracy': ref_acc,
    'referral_sensitivity': sens,
    'referral_specificity': spec,
    'confusion_matrix': conf_mat,
    'timestamp': time.strftime('%Y-%m-%d %H:%M:%S')
}

out_dirs = [
    os.path.join(root_dir, 'models', 'saved'),
    os.path.join(root_dir, 'matlab', 'models', 'saved')
]

for d in out_dirs:
    os.makedirs(d, exist_ok=True)
    mat_path = os.path.join(d, 'dr_random_forest.mat')
    spio.savemat(mat_path, {'model': model_struct, 'metadata': metadata_struct})
    print(f'[SAVED] MATLAB model artifact -> {mat_path}')

# Save JSON metadata
meta_json_path = os.path.join(root_dir, 'models', 'saved', 'dr_model_metadata.json')
json_meta = {
    'feature_names': feature_names,
    'feature_ordering': list(range(1, 13)),
    'class_labels': class_labels,
    'train_count': int(len(df_train)),
    'test_count': int(len(df_test)),
    'accuracy': float(acc),
    'referral_accuracy': float(ref_acc),
    'referral_sensitivity': float(sens),
    'referral_specificity': float(spec),
    'confusion_matrix': conf_mat.tolist(),
    'timestamp': time.strftime('%Y-%m-%d %H:%M:%S')
}
with open(meta_json_path, 'w') as f:
    json.dump(json_meta, f, indent=2)
print(f'[SAVED] Metadata JSON -> {meta_json_path}')

# Save held-out test sample list for testing predict_dr
held_out_path = os.path.join(root_dir, 'models', 'saved', 'held_out_test_samples.json')
held_out_list = []
for _, row in df_test.iterrows():
    held_out_list.append({
        'path': row['path'],
        'grade': int(row['grade']),
        'dataset': row['dataset']
    })
with open(held_out_path, 'w') as f:
    json.dump(held_out_list, f, indent=2)
print(f'[SAVED] Held-out test samples ({len(held_out_list)}) -> {held_out_path}')
print('>>> Retraining on full dataset complete.')
