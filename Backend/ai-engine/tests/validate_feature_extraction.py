"""
SIH26038 - Feature Extraction Pipeline Verification & Visual Summary Generator
Validates 22-dimensional feature extraction across 2 APTOS, 2 IDRiD, and 1 DRIVE samples.
Generates single visual feature summary for a sample IDRiD image in outputs/features/.
"""

import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

def get_base_dir():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

def detect_fov_mask(gray_arr, threshold=15.0):
    return gray_arr > threshold

def extract_color_features_py(img_arr, fov_mask):
    if fov_mask is None or not np.any(fov_mask):
        fov_mask = np.ones((img_arr.shape[0], img_arr.shape[1]), dtype=bool)
        
    r = img_arr[:, :, 0].astype(float)[fov_mask]
    g = img_arr[:, :, 1].astype(float)[fov_mask]
    b = img_arr[:, :, 2].astype(float)[fov_mask]
    
    if r.size == 0:
        return {
            'mean_red': 0.0, 'mean_green': 0.0, 'mean_blue': 0.0,
            'std_red': 0.0, 'std_green': 0.0, 'std_blue': 0.0,
            'green_mean': 0.0, 'green_contrast': 0.0
        }
        
    return {
        'mean_red': float(np.mean(r)),
        'mean_green': float(np.mean(g)),
        'mean_blue': float(np.mean(b)),
        'std_red': float(np.std(r)),
        'std_green': float(np.std(g)),
        'std_blue': float(np.std(b)),
        'green_mean': float(np.mean(g)),
        'green_contrast': float(np.std(g))
    }

def compute_glcm_py(gray_u8, num_levels=16, offsets=[(0, 1), (-1, 1), (-1, 0), (-1, -1)]):
    # Quantize to num_levels
    q = np.clip((gray_u8.astype(float) / 256.0 * num_levels).astype(int), 0, num_levels - 1)
    H, W = q.shape
    
    contrasts, correlations, energies, homogeneities = [], [], [], []
    
    for dy, dx in offsets:
        # Construct co-occurrence matrix
        y_start = max(0, -dy)
        y_end = min(H, H - dy) if dy >= 0 else H
        x_start = max(0, -dx)
        x_end = min(W, W - dx) if dx >= 0 else W
        
        y_target = y_start + dy
        y_target_end = y_end + dy
        x_target = x_start + dx
        x_target_end = x_end + dx
        
        orig = q[y_start:y_end, x_start:x_end].ravel()
        neighbor = q[y_target:y_target_end, x_target:x_target_end].ravel()
        
        # 2D histogram
        glcm, _, _ = np.histogram2d(orig, neighbor, bins=num_levels, range=[[0, num_levels], [0, num_levels]])
        total = glcm.sum()
        if total == 0:
            continue
        p = glcm / total
        
        # Grid of indices
        i, j = np.indices((num_levels, num_levels))
        
        # Contrast: sum(p_ij * (i - j)^2)
        contrast = np.sum(p * ((i - j) ** 2))
        contrasts.append(contrast)
        
        # Homogeneity: sum(p_ij / (1 + |i - j|))
        homo = np.sum(p / (1.0 + np.abs(i - j)))
        homogeneities.append(homo)
        
        # Energy: sum(p_ij^2)
        energy = np.sum(p ** 2)
        energies.append(energy)
        
        # Correlation
        mu_i = np.sum(i * p)
        mu_j = np.sum(j * p)
        var_i = np.sum(((i - mu_i) ** 2) * p)
        var_j = np.sum(((j - mu_j) ** 2) * p)
        std_i = np.sqrt(var_i)
        std_j = np.sqrt(var_j)
        if std_i > 0 and std_j > 0:
            corr = np.sum((i - mu_i) * (j - mu_j) * p) / (std_i * std_j)
        else:
            corr = 1.0
        correlations.append(corr)
        
    return {
        'glcm_contrast': float(np.mean(contrasts)) if contrasts else 0.0,
        'glcm_correlation': float(np.mean(correlations)) if correlations else 0.0,
        'glcm_energy': float(np.mean(energies)) if energies else 0.0,
        'glcm_homogeneity': float(np.mean(homogeneities)) if homogeneities else 0.0
    }

def extract_vessel_features_py(vessel_mask, fov_mask):
    if vessel_mask is None or not np.any(vessel_mask) or fov_mask is None or not np.any(fov_mask):
        return {'vessel_density': 0.0, 'vessel_edge_density': 0.0}
        
    if vessel_mask.shape != fov_mask.shape:
        pil_v = Image.fromarray((vessel_mask > 0).astype(np.uint8) * 255)
        vessel_mask = np.array(pil_v.resize((fov_mask.shape[1], fov_mask.shape[0]), Image.Resampling.NEAREST)) > 0
        
    retina_area = max(1, int(np.sum(fov_mask)))
    vessel_in_fov = (vessel_mask > 0) & fov_mask
    vessel_px = int(np.sum(vessel_in_fov))
    
    # Edges
    pil_in = Image.fromarray(vessel_in_fov.astype(np.uint8) * 255)
    edges = np.array(pil_in.filter(ImageFilter.FIND_EDGES)) > 100
    edge_px = int(np.sum(edges & fov_mask))
    
    return {
        'vessel_density': float(vessel_px / retina_area),
        'vessel_edge_density': float(edge_px / retina_area)
    }

def count_connected_components_py(bin_mask):
    # Simple BFS connected component labeling
    H, W = bin_mask.shape
    visited = np.zeros_like(bin_mask, dtype=bool)
    count = 0
    for r in range(H):
        for c in range(W):
            if bin_mask[r, c] and not visited[r, c]:
                count += 1
                queue = [(r, c)]
                visited[r, c] = True
                while queue:
                    cr, cc = queue.pop()
                    for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                        nr, nc = cr + dr, cc + dc
                        if 0 <= nr < H and 0 <= nc < W:
                            if bin_mask[nr, nc] and not visited[nr, nc]:
                                visited[nr, nc] = True
                                queue.append((nr, nc))
    return count

def extract_lesion_features_py(masks, fov_mask):
    feats = {
        'microaneurysm_area': 0.0, 'microaneurysm_count': 0.0,
        'hemorrhage_area': 0.0, 'hemorrhage_count': 0.0,
        'hard_exudate_area': 0.0, 'hard_exudate_count': 0.0,
        'soft_exudate_area': 0.0, 'soft_exudate_count': 0.0
    }
    
    if not masks or fov_mask is None or not np.any(fov_mask):
        return feats
        
    retina_area = max(1, int(np.sum(fov_mask)))
    H, W = fov_mask.shape
    
    mapping = [
        (('ma_mask', 'microaneurysms', 'ma'), 'microaneurysm_area', 'microaneurysm_count'),
        (('he_mask', 'haemorrhages', 'hemorrhages', 'he'), 'hemorrhage_area', 'hemorrhage_count'),
        (('ex_mask', 'hard_exudates', 'exudates', 'ex'), 'hard_exudate_area', 'hard_exudate_count'),
        (('se_mask', 'soft_exudates', 'cotton_wool_spots', 'se'), 'soft_exudate_area', 'soft_exudate_count')
    ]
    
    for keys, area_key, count_key in mapping:
        mask_arr = None
        for k in keys:
            if k in masks and masks[k] is not None:
                mask_arr = masks[k]
                break
        if mask_arr is not None and np.any(mask_arr):
            if mask_arr.shape != (H, W):
                pil_m = Image.fromarray((mask_arr > 0).astype(np.uint8) * 255)
                mask_arr = np.array(pil_m.resize((W, H), Image.Resampling.NEAREST)) > 0
            valid = (mask_arr > 0) & fov_mask
            feats[area_key] = float(np.sum(valid) / retina_area)
            feats[count_key] = float(count_connected_components_py(valid))
            
    return feats

def extract_features_py(img_arr, optional_masks=None):
    if optional_masks is None:
        optional_masks = {}
        
    gray = 0.2989 * img_arr[:, :, 0] + 0.5870 * img_arr[:, :, 1] + 0.1140 * img_arr[:, :, 2]
    fov_mask = detect_fov_mask(gray)
    green_ch = img_arr[:, :, 1]
    
    color_feats = extract_color_features_py(img_arr, fov_mask)
    texture_feats = compute_glcm_py(green_ch, num_levels=16)
    vessel_feats = extract_vessel_features_py(optional_masks.get('vessel_mask'), fov_mask)
    lesion_feats = extract_lesion_features_py(optional_masks, fov_mask)
    
    names = [
        'mean_red', 'mean_green', 'mean_blue',
        'std_red', 'std_green', 'std_blue',
        'green_mean', 'green_contrast',
        'glcm_contrast', 'glcm_correlation', 'glcm_energy', 'glcm_homogeneity',
        'vessel_density', 'vessel_edge_density',
        'microaneurysm_area', 'microaneurysm_count',
        'hemorrhage_area', 'hemorrhage_count',
        'hard_exudate_area', 'hard_exudate_count',
        'soft_exudate_area', 'soft_exudate_count'
    ]
    
    vec = [
        color_feats['mean_red'], color_feats['mean_green'], color_feats['mean_blue'],
        color_feats['std_red'], color_feats['std_green'], color_feats['std_blue'],
        color_feats['green_mean'], color_feats['green_contrast'],
        texture_feats['glcm_contrast'], texture_feats['glcm_correlation'],
        texture_feats['glcm_energy'], texture_feats['glcm_homogeneity'],
        vessel_feats['vessel_density'], vessel_feats['vessel_edge_density'],
        lesion_feats['microaneurysm_area'], lesion_feats['microaneurysm_count'],
        lesion_feats['hemorrhage_area'], lesion_feats['hemorrhage_count'],
        lesion_feats['hard_exudate_area'], lesion_feats['hard_exudate_count'],
        lesion_feats['soft_exudate_area'], lesion_feats['soft_exudate_count']
    ]
    
    return {
        'color': color_feats,
        'texture': texture_feats,
        'vessel': vessel_feats,
        'lesion': lesion_feats,
        'vector': np.array(vec, dtype=float),
        'names': names,
        'num_features': len(vec)
    }

def render_idrid_visual_summary(img_arr, masks, feats, save_path):
    # 3 panels: [Retinal Image] | [Lesion Overlay] | [Feature Values Panel]
    h_panel, w_panel = 400, 400
    card_h = 500
    card_w = 1260
    
    card = Image.new('RGB', (card_w, card_h), (18, 22, 30))
    draw = ImageDraw.Draw(card)
    
    # 1. Image panel
    pil_img = Image.fromarray(img_arr).resize((w_panel, h_panel), Image.Resampling.BICUBIC)
    card.paste(pil_img, (20, 60))
    draw.text((20, 25), "1. Retinal Image (IDRiD_01 - 512x512)", fill=(255, 255, 255))
    
    # 2. Lesion Overlay panel
    overlay_arr = np.array(pil_img).copy().astype(float)
    H, W = img_arr.shape[:2]
    
    # EX (Yellow)
    if 'ex_mask' in masks and masks['ex_mask'] is not None:
        m = Image.fromarray((masks['ex_mask'] > 0).astype(np.uint8) * 255).resize((w_panel, h_panel), Image.Resampling.NEAREST)
        m_arr = np.array(m) > 0
        overlay_arr[m_arr, 0] = overlay_arr[m_arr, 0] * 0.3 + 255 * 0.7
        overlay_arr[m_arr, 1] = overlay_arr[m_arr, 1] * 0.3 + 255 * 0.7
        overlay_arr[m_arr, 2] = overlay_arr[m_arr, 2] * 0.3 + 0 * 0.7
        
    # HE (Red)
    if 'he_mask' in masks and masks['he_mask'] is not None:
        m = Image.fromarray((masks['he_mask'] > 0).astype(np.uint8) * 255).resize((w_panel, h_panel), Image.Resampling.NEAREST)
        m_arr = np.array(m) > 0
        overlay_arr[m_arr, 0] = overlay_arr[m_arr, 0] * 0.3 + 255 * 0.7
        overlay_arr[m_arr, 1] = overlay_arr[m_arr, 1] * 0.3 + 30 * 0.7
        overlay_arr[m_arr, 2] = overlay_arr[m_arr, 2] * 0.3 + 30 * 0.7

    # MA (Cyan)
    if 'ma_mask' in masks and masks['ma_mask'] is not None:
        m = Image.fromarray((masks['ma_mask'] > 0).astype(np.uint8) * 255).resize((w_panel, h_panel), Image.Resampling.NEAREST)
        m_arr = np.array(m) > 0
        overlay_arr[m_arr, 0] = overlay_arr[m_arr, 0] * 0.3 + 0 * 0.7
        overlay_arr[m_arr, 1] = overlay_arr[m_arr, 1] * 0.3 + 255 * 0.7
        overlay_arr[m_arr, 2] = overlay_arr[m_arr, 2] * 0.3 + 255 * 0.7

    overlay_img = Image.fromarray(np.clip(overlay_arr, 0, 255).astype(np.uint8))
    card.paste(overlay_img, (440, 60))
    draw.text((440, 25), "2. Lesion Evidence Overlay (Yellow: EX | Red: HE | Cyan: MA)", fill=(255, 255, 255))
    
    # 3. Features Panel
    p_x = 860
    p_y = 60
    draw.rectangle([p_x, p_y, card_w - 20, card_h - 20], fill=(26, 32, 44), outline=(45, 55, 72))
    
    draw.text((p_x + 16, p_y + 16), "3. Extracted Biomarker Vector (22-D)", fill=(255, 255, 255))
    draw.text((p_x + 16, p_y + 36), "Prototype Traditional Machine Learning Features", fill=(148, 163, 184))
    
    y = p_y + 64
    # Color
    draw.text((p_x + 16, y), "[Color Features - 8]", fill=(56, 189, 248))
    y += 18
    draw.text((p_x + 24, y), f"Mean RGB: [{feats['color']['mean_red']:.1f}, {feats['color']['mean_green']:.1f}, {feats['color']['mean_blue']:.1f}]", fill=(203, 213, 225))
    y += 16
    draw.text((p_x + 24, y), f"Std RGB:  [{feats['color']['std_red']:.1f}, {feats['color']['std_green']:.1f}, {feats['color']['std_blue']:.1f}]", fill=(203, 213, 225))
    y += 16
    draw.text((p_x + 24, y), f"Green Mean: {feats['color']['green_mean']:.1f} | Green Contrast: {feats['color']['green_contrast']:.1f}", fill=(203, 213, 225))
    y += 24
    
    # Texture
    draw.text((p_x + 16, y), "[Texture Features (GLCM) - 4]", fill=(74, 222, 128))
    y += 18
    draw.text((p_x + 24, y), f"Contrast: {feats['texture']['glcm_contrast']:.2f} | Correlation: {feats['texture']['glcm_correlation']:.3f}", fill=(203, 213, 225))
    y += 16
    draw.text((p_x + 24, y), f"Energy: {feats['texture']['glcm_energy']:.3f} | Homogeneity: {feats['texture']['glcm_homogeneity']:.3f}", fill=(203, 213, 225))
    y += 24
    
    # Vessel
    draw.text((p_x + 16, y), "[Vessel Features - 2]", fill=(251, 146, 60))
    y += 18
    draw.text((p_x + 24, y), f"Vessel Density: {feats['vessel']['vessel_density']:.4f} | Edge Density: {feats['vessel']['vessel_edge_density']:.4f}", fill=(203, 213, 225))
    y += 24
    
    # Lesion
    draw.text((p_x + 16, y), "[Lesion Evidence - 8]", fill=(248, 113, 113))
    y += 18
    draw.text((p_x + 24, y), f"Hard Exudates: Area={feats['lesion']['hard_exudate_area']:.4f} (Count={int(feats['lesion']['hard_exudate_count'])})", fill=(203, 213, 225))
    y += 16
    draw.text((p_x + 24, y), f"Hemorrhages:   Area={feats['lesion']['hemorrhage_area']:.4f} (Count={int(feats['lesion']['hemorrhage_count'])})", fill=(203, 213, 225))
    y += 16
    draw.text((p_x + 24, y), f"Microaneurysms: Area={feats['lesion']['microaneurysm_area']:.4f} (Count={int(feats['lesion']['microaneurysm_count'])})", fill=(203, 213, 225))
    y += 16
    draw.text((p_x + 24, y), f"Soft Exudates:  Area={feats['lesion']['soft_exudate_area']:.4f} (Count={int(feats['lesion']['soft_exudate_count'])})", fill=(203, 213, 225))
    
    card.save(save_path, format='PNG', quality=95)
    print(f"  [SAVED] Visual feature summary -> {save_path}")

def run_tests():
    base_dir = get_base_dir()
    out_dir = os.path.join(base_dir, 'outputs', 'features')
    os.makedirs(out_dir, exist_ok=True)
    
    print("=" * 70)
    print("        RETINO-AI FEATURE EXTRACTION TEST SUITE (PHASE 3)")
    print("=" * 70)
    
    samples = [
        {
            'dataset': 'APTOS',
            'id': 'APTOS_1',
            'img_path': os.path.join(base_dir, 'data', 'raw', 'aptos', 'train_images', '000c1434d8d7.png'),
            'masks': {}
        },
        {
            'dataset': 'APTOS',
            'id': 'APTOS_2',
            'img_path': os.path.join(base_dir, 'data', 'raw', 'aptos', 'train_images', '001639a390f0.png'),
            'masks': {}
        },
        {
            'dataset': 'IDRiD',
            'id': 'IDRiD_01',
            'img_path': os.path.join(base_dir, 'data', 'raw', 'idrid', 'Segmentation', '1. Original Images', 'a. Training Set', 'IDRiD_01.jpg'),
            'masks': {
                'ma_mask': os.path.join(base_dir, 'data', 'raw', 'idrid', 'Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '1. Microaneurysms', 'IDRiD_01_MA.tif'),
                'he_mask': os.path.join(base_dir, 'data', 'raw', 'idrid', 'Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '2. Haemorrhages', 'IDRiD_01_HE.tif'),
                'ex_mask': os.path.join(base_dir, 'data', 'raw', 'idrid', 'Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '3. Hard Exudates', 'IDRiD_01_EX.tif')
            }
        },
        {
            'dataset': 'IDRiD',
            'id': 'IDRiD_03',
            'img_path': os.path.join(base_dir, 'data', 'raw', 'idrid', 'Segmentation', '1. Original Images', 'a. Training Set', 'IDRiD_03.jpg'),
            'masks': {
                'ma_mask': os.path.join(base_dir, 'data', 'raw', 'idrid', 'Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '1. Microaneurysms', 'IDRiD_03_MA.tif'),
                'he_mask': os.path.join(base_dir, 'data', 'raw', 'idrid', 'Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '2. Haemorrhages', 'IDRiD_03_HE.tif'),
                'ex_mask': os.path.join(base_dir, 'data', 'raw', 'idrid', 'Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '3. Hard Exudates', 'IDRiD_03_EX.tif'),
                'se_mask': os.path.join(base_dir, 'data', 'raw', 'idrid', 'Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '4. Soft Exudates', 'IDRiD_03_SE.tif')
            }
        },
        {
            'dataset': 'DRIVE',
            'id': 'DRIVE_21',
            'img_path': os.path.join(base_dir, 'data', 'raw', 'drive', 'training', 'images', '21_training.tif'),
            'masks': {
                'vessel_mask': os.path.join(base_dir, 'data', 'raw', 'drive', 'training', '1st_manual', '21_manual1.gif')
            }
        }
    ]
    
    saved_visual = False
    
    for s in samples:
        ds = s['dataset']
        sid = s['id']
        p = s['img_path']
        print(f"\n--- Testing {ds} ({sid}) ---")
        
        assert os.path.exists(p), f"Sample image file missing: {p}"
        
        im = Image.open(p).convert('RGB').resize((512, 512), Image.Resampling.BICUBIC)
        arr = np.array(im, dtype=np.uint8)
        
        # Load masks
        loaded_masks = {}
        for m_name, m_path in s['masks'].items():
            if os.path.exists(m_path):
                loaded_masks[m_name] = np.array(Image.open(m_path)) > 0
                
        # Extract features
        res = extract_features_py(arr, loaded_masks)
        
        # Assertions
        vec = res['vector']
        names = res['names']
        
        assert isinstance(vec, np.ndarray), "Vector must be numpy array"
        assert vec.dtype == float, "Vector must be float type"
        assert vec.shape == (22,), f"Vector length must be 22, got {vec.shape}"
        assert np.all(np.isfinite(vec)), "Feature vector must contain only finite numbers (no NaN/Inf)"
        assert len(names) == len(vec), "Names length must match vector length"
        assert res['num_features'] == 22, "num_features must be 22"
        
        # Color assertions
        assert res['color']['mean_green'] > 0, "mean_green must be > 0"
        assert res['color']['green_contrast'] > 0, "green_contrast must be > 0"
        
        # Texture assertions
        assert res['texture']['glcm_contrast'] > 0, "glcm_contrast must be > 0"
        assert res['texture']['glcm_homogeneity'] > 0, "glcm_homogeneity must be > 0"
        
        # Vessel assertions for DRIVE
        if ds == 'DRIVE':
            assert res['vessel']['vessel_density'] > 0, "DRIVE vessel_density must be > 0"
            assert res['vessel']['vessel_edge_density'] > 0, "DRIVE vessel_edge_density must be > 0"
            print(f"  [PASS] DRIVE Vessels: Density={res['vessel']['vessel_density']:.4f}, Edge Density={res['vessel']['vessel_edge_density']:.4f}")
            
        # Lesion assertions for IDRiD
        if ds == 'IDRiD':
            assert res['lesion']['hard_exudate_area'] > 0, "IDRiD hard_exudate_area must be > 0"
            assert res['lesion']['hard_exudate_count'] > 0, "IDRiD hard_exudate_count must be > 0"
            print(f"  [PASS] IDRiD Lesions: EX Area={res['lesion']['hard_exudate_area']:.4f}, Count={res['lesion']['hard_exudate_count']} | MA Count={res['lesion']['microaneurysm_count']}")
            
        # Determinism check
        res2 = extract_features_py(arr, loaded_masks)
        assert np.array_equal(vec, res2['vector']), "Feature extraction must be strictly deterministic"
        
        print(f"  [PASS] 22-D Feature Vector verified. Mean Green: {res['color']['green_mean']:.1f}, GLCM Contrast: {res['texture']['glcm_contrast']:.2f}")
        
        # Render the one visual feature summary for sample IDRiD_01
        if sid == 'IDRiD_01' and not saved_visual:
            visual_path = os.path.join(out_dir, 'idrid_feature_summary.png')
            render_idrid_visual_summary(arr, loaded_masks, res, visual_path)
            saved_visual = True
            
    print("\n" + "=" * 70)
    print(">>> ALL FEATURE EXTRACTION TESTS PASSED (5/5 samples)!")
    print(">>> Standardized Prototype Vector: 22 Features")
    print(f">>> Single IDRiD visual summary saved at: {os.path.join(out_dir, 'idrid_feature_summary.png')}")
    print("=" * 70)

if __name__ == '__main__':
    run_tests()
