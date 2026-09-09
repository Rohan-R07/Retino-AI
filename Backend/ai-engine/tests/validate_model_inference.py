"""
Retino-AI: Model Inference Validation Test Suite (Phase 4 Prototype)
Verifies predict_dr inference on held-out images using models/saved/dr_random_forest.mat.
"""
import os
import sys
import json
import numpy as np
from PIL import Image
from scipy import io as spio

print("======================================================================")
print("       RETINO-AI MODEL INFERENCE TEST SUITE (PHASE 4 PROTOTYPE)       ")
print("======================================================================")

this_dir = os.path.dirname(os.path.abspath(__file__))
root_dir = os.path.dirname(this_dir)

# 1. Check model file existence
mat_path = os.path.join(root_dir, 'models', 'saved', 'dr_random_forest.mat')
if not os.path.exists(mat_path):
    mat_path = os.path.join(root_dir, 'matlab', 'models', 'saved', 'dr_random_forest.mat')

if not os.path.exists(mat_path):
    print(f"[FAIL] Trained model artifact not found at {mat_path}")
    sys.exit(1)

print(f"[LOAD] Loading trained model artifact -> {mat_path}")
mat_data = spio.loadmat(mat_path, simplify_cells=True)
model = mat_data['model']
metadata = mat_data['metadata']

feature_names = list(model['feature_names'])
classes = list(model['classes'])
print(f"[MODEL] Model type: {model['type']} | Classes: {classes}")
print(f"[MODEL] Features ({len(feature_names)}): {feature_names}")
print(f"[MODEL] Training samples: {model['training_samples']} | Test samples: {model['test_samples']}")
print(f"[MODEL] Test accuracy: {model['accuracy'] * 100:.2f}% | Referral accuracy: {model['referral_accuracy'] * 100:.2f}%")

# Feature extractor matching extract_features.m
def extract_12_features(img_arr):
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

# predict_dr Python counterpart
def predict_dr(image_input, model_struct):
    result = {
        'status': 'INITIALIZED',
        'is_gradable': False,
        'predicted_grade': None,
        'class_probabilities': None,
        'confidence': 0.0,
        'feature_vector': None,
        'feature_names': feature_names,
        'referral_recommended': False,
        'advisory': ''
    }

    if isinstance(image_input, str):
        if not os.path.exists(image_input):
            result['status'] = 'FILE_NOT_FOUND'
            result['advisory'] = f'File not found: {image_input}'
            return result
        img = Image.open(image_input).convert('RGB')
        img_arr = np.array(img.resize((512, 512)), dtype=np.uint8)
    else:
        img_arr = np.array(image_input, dtype=np.uint8)

    # 1. Quality Assessment Gatekeeper
    gray = (0.2989 * img_arr[:, :, 0] + 0.5870 * img_arr[:, :, 1] + 0.1140 * img_arr[:, :, 2]).astype(np.uint8)
    mean_lum = float(np.mean(gray))
    if mean_lum < 15.0: # Intentionally dark / underexposed
        result['status'] = 'UNGRADABLE'
        result['is_gradable'] = False
        result['advisory'] = f'Severe underexposure detected (Mean luminance: {mean_lum:.1f} < 15.0).'
        return result

    result['is_gradable'] = True

    # 2. Feature Extraction
    feat_vec = extract_12_features(img_arr)
    result['feature_vector'] = feat_vec

    # 3. Decision Tree Ensemble Traversal
    trees = model_struct['trees']
    n_trees = len(trees)
    probs = np.zeros(5, dtype=np.float64)

    for tr in trees:
        c_left = tr['children_left']
        c_right = tr['children_right']
        feats = tr['feature']
        threshs = tr['threshold']
        vals = tr['value']

        node = 0
        while node < len(feats) and c_left[node] >= 0:
            f = feats[node]
            th = threshs[node]
            if feat_vec[f] <= th:
                node = c_left[node]
            else:
                node = c_right[node]

        v = vals[node]
        s_v = np.sum(v)
        if s_v > 0:
            probs += (v / s_v)
        else:
            probs += 0.2

    probs /= n_trees
    probs /= np.sum(probs) # Normalize

    pred_grade = int(np.argmax(probs))
    conf = float(np.max(probs))

    result['predicted_grade'] = pred_grade
    result['class_probabilities'] = probs.tolist()
    result['confidence'] = conf
    result['referral_recommended'] = bool(pred_grade >= 2)
    result['status'] = 'GRADABLE'
    result['advisory'] = f'DR Grade {pred_grade} predicted with {conf*100:.1f}% confidence.'
    return result

# 2. Load held-out test samples
held_out_file = os.path.join(root_dir, 'models', 'saved', 'held_out_test_samples.json')
with open(held_out_file, 'r') as f:
    held_out_samples = json.load(f)

# Pick 2 samples from each DR severity grade (0 to 4) for balanced testing
diverse_test_samples = []
for g in range(5):
    sub = [s for s in held_out_samples if s['grade'] == g]
    diverse_test_samples.extend(sub[:2])

print(f"\n--- Testing predict_dr on {len(diverse_test_samples)} Held-Out Unseen Images (Grades 0-4) ---")
all_passed = True
test_count = 0
pass_count = 0

for i, sample in enumerate(diverse_test_samples):
    test_count += 1
    p = sample['path']
    actual_grade = sample['grade']
    dataset = sample['dataset']
    fname = os.path.basename(p)

    res = predict_dr(p, model)

    # Check 1: Gradable
    c1 = res['is_gradable'] is True and res['status'] == 'GRADABLE'
    # Check 2: Valid DR Grade
    c2 = res['predicted_grade'] in [0, 1, 2, 3, 4]
    # Check 3: Valid Probabilities
    c3 = abs(sum(res['class_probabilities']) - 1.0) < 1e-4 and all(x >= 0 for x in res['class_probabilities'])
    # Check 4: Valid Confidence
    c4 = 0.0 <= res['confidence'] <= 1.0
    # Check 5: Exactly 12 Features
    c5 = len(res['feature_vector']) == 12
    # Check 6: No NaN / Inf
    c6 = all(np.isfinite(x) for x in res['feature_vector'])
    # Check 7: Determinism
    res2 = predict_dr(p, model)
    c7 = res['predicted_grade'] == res2['predicted_grade'] and res['feature_vector'] == res2['feature_vector']

    sample_ok = c1 and c2 and c3 and c4 and c5 and c6 and c7
    if sample_ok:
        pass_count += 1
        probs_str = " ".join([f"{x:.3f}" for x in res['class_probabilities']])
        print(f"  [PASS] Sample {i+1} ({dataset} {fname}): Actual Grade={actual_grade} | "
              f"Pred Grade={res['predicted_grade']} | Conf={res['confidence']*100:.1f}% | "
              f"Referral={'YES' if res['referral_recommended'] else 'NO'} | Probs=[{probs_str}]")
    else:
        all_passed = False
        print(f"  [FAIL] Sample {i+1} ({fname}): Failed verification checks!")

# 3. Test Quality Gate on Intentionally Poor Quality Image
print("\n--- Testing Quality Gate on Intentionally Poor Quality Image ---")
test_count += 1
dark_img = np.zeros((512, 512, 3), dtype=np.uint8)
res_dark = predict_dr(dark_img, model)
dark_ok = (res_dark['is_gradable'] is False and
           res_dark['status'] == 'UNGRADABLE' and
           res_dark['predicted_grade'] is None)

if dark_ok:
    pass_count += 1
    print(f"  [PASS] Quality gate properly tripped on dark image: status={res_dark['status']}")
    print(f"         Advisory: {res_dark['advisory']}")
else:
    all_passed = False
    print("  [FAIL] Quality gate failed to flag ungradable image!")

print("\n======================================================================")
print(f"TEST RESULT: {pass_count} / {test_count} Tests Passed")
if all_passed:
    print(">>> ALL MODEL INFERENCE AND QUALITY GATE VERIFICATIONS PASSED!")
else:
    print(">>> SOME TESTS FAILED")
print("======================================================================")
