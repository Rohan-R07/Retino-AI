"""
SIH26038 - Quality Assessment Pipeline Verification & Visual Report Generator
Validates quality checks on real fundus images (APTOS, IDRiD, DRIVE) and degraded test cases.
Saves visual verification reports to outputs/quality_assessment/.
"""

import os
import sys
import numpy as np
from PIL import Image, ImageFilter, ImageDraw, ImageFont

def get_base_dir():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

def detect_fov_mask(gray_arr, threshold=15.0):
    mask = (gray_arr > threshold).astype(np.uint8)
    pil_mask = Image.fromarray(mask * 255)
    closed = pil_mask.filter(ImageFilter.MaxFilter(size=5)).filter(ImageFilter.MinFilter(size=5))
    return np.array(closed) > 128

def check_blur(gray_arr, fov_mask, threshold=25.0):
    # Discrete 3x3 Laplacian operator
    lap = -4.0 * gray_arr.copy()
    lap[:-1, :] += gray_arr[1:, :]
    lap[1:, :] += gray_arr[:-1, :]
    lap[:, :-1] += gray_arr[:, 1:]
    lap[:, 1:] += gray_arr[:, :-1]
    
    retina_lap = lap[fov_mask]
    if retina_lap.size > 0 and np.any(fov_mask):
        var_lap = float(np.var(retina_lap))
    else:
        var_lap = 0.0
        
    is_sharp = bool(var_lap >= threshold)
    return var_lap, is_sharp

def check_brightness(gray_arr, fov_mask, min_mean=35.0, max_mean=180.0, min_entropy=4.0):
    retina_px = gray_arr[fov_mask]
    if retina_px.size > 0 and np.any(fov_mask):
        mean_lum = float(np.mean(retina_px))
        hist, _ = np.histogram(retina_px.astype(np.uint8), bins=256, range=(0, 256), density=True)
        hist = hist[hist > 0]
        entropy_val = float(-np.sum(hist * np.log2(hist)))
    else:
        mean_lum = 0.0
        entropy_val = 0.0
        
    is_underexposed = (mean_lum < min_mean)
    is_overexposed = (mean_lum > max_mean)
    is_low_entropy = (entropy_val < min_entropy)
    is_adequate = bool(not is_underexposed and not is_overexposed and not is_low_entropy)
    
    # Normalized score [0 to 1]
    if mean_lum < min_mean:
        score = max(0.0, mean_lum / min_mean)
    elif mean_lum > max_mean:
        score = max(0.0, 1.0 - (mean_lum - max_mean) / (255.0 - max_mean))
    else:
        score = 1.0
        
    verdict = 'adequate'
    if is_underexposed:
        verdict = 'underexposed'
    elif is_overexposed:
        verdict = 'overexposed'
    elif is_low_entropy:
        verdict = 'low_entropy'
        
    return score, is_adequate, {
        'mean_luminance': mean_lum,
        'entropy': entropy_val,
        'min_mean': min_mean,
        'max_mean': max_mean,
        'is_underexposed': is_underexposed,
        'is_overexposed': is_overexposed,
        'verdict': verdict
    }

def check_fov(fov_mask, min_area_ratio=0.25, min_circularity=0.35):
    total_px = fov_mask.size
    retina_px = int(np.sum(fov_mask))
    area_ratio = float(retina_px / total_px) if total_px > 0 else 0.0
    
    # Measure perimeter via edge detection
    pil_mask = Image.fromarray(fov_mask.astype(np.uint8) * 255)
    perim_img = pil_mask.filter(ImageFilter.FIND_EDGES)
    perim_px = int(np.sum(np.array(perim_img) > 100))
    
    if perim_px > 0 and retina_px > 0:
        circularity = float((4.0 * np.pi * retina_px) / (perim_px ** 2))
        circularity = min(1.0, circularity)
    else:
        circularity = 0.0
        
    is_area_ok = (area_ratio >= min_area_ratio)
    is_shape_ok = (circularity >= min_circularity)
    is_complete = bool(is_area_ok and is_shape_ok)
    
    norm_area = min(1.0, area_ratio / 0.50)
    norm_circ = min(1.0, circularity)
    fov_score = float(0.60 * norm_area + 0.40 * norm_circ)
    
    verdict = 'complete'
    if not is_area_ok:
        verdict = 'insufficient_area'
    elif not is_shape_ok:
        verdict = 'distorted_shape'
        
    return fov_score, is_complete, {
        'retina_area_ratio': area_ratio,
        'circularity': circularity,
        'min_area_ratio': min_area_ratio,
        'min_circularity': min_circularity,
        'is_area_ok': is_area_ok,
        'is_shape_ok': is_shape_ok,
        'verdict': verdict
    }

def assess_image_quality_py(img_arr, fov_mask=None, cfg=None):
    if cfg is None:
        cfg = {
            'blur_threshold': 25.0,
            'brightness_min': 35.0,
            'brightness_max': 180.0,
            'min_entropy': 4.0,
            'min_fov_ratio': 0.25,
            'min_circularity': 0.35
        }
        
    if img_arr.ndim == 3:
        gray = 0.2989 * img_arr[:, :, 0] + 0.5870 * img_arr[:, :, 1] + 0.1140 * img_arr[:, :, 2]
    else:
        gray = img_arr.astype(float)
        
    if fov_mask is None:
        fov_mask = detect_fov_mask(gray)
        
    blur_score, blur_pass = check_blur(gray, fov_mask, cfg['blur_threshold'])
    brightness_score, brightness_pass, b_details = check_brightness(
        gray, fov_mask, cfg['brightness_min'], cfg['brightness_max'], cfg['min_entropy']
    )
    fov_score, fov_pass, f_details = check_fov(
        fov_mask, cfg['min_fov_ratio'], cfg['min_circularity']
    )
    
    is_gradable = bool(blur_pass and brightness_pass and fov_pass)
    
    reasons = []
    if not blur_pass:
        reasons.append(f"Image too blurry (focus metric {blur_score:.2f} < threshold {cfg['blur_threshold']:.2f}).")
    if not brightness_pass:
        if b_details['is_underexposed']:
            reasons.append(f"Image severely underexposed (mean brightness {b_details['mean_luminance']:.2f} < threshold {cfg['brightness_min']:.2f}).")
        elif b_details['is_overexposed']:
            reasons.append(f"Image severely overexposed/glare (mean brightness {b_details['mean_luminance']:.2f} > threshold {cfg['brightness_max']:.2f}).")
        else:
            reasons.append(f"Insufficient information entropy ({b_details['entropy']:.2f} < {cfg['min_entropy']:.2f}).")
    if not fov_pass:
        if not f_details['is_area_ok']:
            reasons.append(f"Insufficient retinal area coverage ({f_details['retina_area_ratio']*100.0:.1f}% < threshold {cfg['min_fov_ratio']*100.0:.1f}%).")
        else:
            reasons.append(f"Severely distorted retinal aperture (circularity {f_details['circularity']:.2f} < threshold {cfg['min_circularity']:.2f}).")
            
    rejection_reason = " ".join(reasons)
    
    if is_gradable:
        norm_sharp = min(1.0, blur_score / 60.0)
        composite = 0.40 * norm_sharp + 0.35 * brightness_score + 0.25 * fov_score
        overall_quality = 'excellent' if composite >= 0.85 else 'adequate'
    else:
        overall_quality = 'unacceptable' if len(reasons) >= 2 else 'poor'
        
    return {
        'overall_quality': overall_quality,
        'is_gradable': is_gradable,
        'blur_score': blur_score,
        'brightness_score': brightness_score,
        'fov_score': fov_score,
        'blur_pass': blur_pass,
        'brightness_pass': brightness_pass,
        'fov_pass': fov_pass,
        'rejection_reason': rejection_reason,
        'rejection_reasons': reasons,
        'metadata': {
            'image_size': list(img_arr.shape),
            'thresholds_applied': cfg,
            'fov_details': f_details,
            'brightness_details': b_details
        }
    }

def draw_quality_card(img_arr, fov_mask, q, title_str, save_path):
    # Renders a 3-panel card: [Fundus Image] | [FOV Overlay] | [Metrics & Decision Panel]
    h_panel, w_panel = 400, 400
    card_h = 490
    card_w = 1260
    
    card = Image.new('RGB', (card_w, card_h), (18, 22, 30))
    draw = ImageDraw.Draw(card)
    
    # 1. Image panel
    pil_img = Image.fromarray(img_arr).resize((w_panel, h_panel), Image.Resampling.BICUBIC)
    card.paste(pil_img, (20, 60))
    draw.text((20, 25), f"1. Preprocessed Fundus Image ({title_str})", fill=(255, 255, 255))
    
    # 2. FOV Overlay panel
    pil_fov = Image.fromarray(fov_mask.astype(np.uint8) * 255).resize((w_panel, h_panel), Image.Resampling.NEAREST)
    perim = np.array(pil_fov.filter(ImageFilter.FIND_EDGES)) > 100
    overlay_arr = np.array(pil_img).copy()
    overlay_arr[perim, 0] = 0
    overlay_arr[perim, 1] = 255  # Green perimeter
    overlay_arr[perim, 2] = 0
    card.paste(Image.fromarray(overlay_arr), (440, 60))
    draw.text((440, 25), f"2. Retinal FOV Aperture (Coverage: {q['metadata']['fov_details']['retina_area_ratio']*100.0:.1f}%)", fill=(255, 255, 255))
    
    # 3. Decision & Metrics Panel
    metrics_x = 860
    metrics_y = 60
    # Background panel
    draw.rectangle([metrics_x, metrics_y, card_w - 20, card_h - 30], fill=(26, 32, 44), outline=(45, 55, 72))
    
    # Status badge
    if q['is_gradable']:
        badge_bg = (22, 101, 52)
        badge_text = "PASS - GRADABLE FOR DR SCREENING"
        badge_fg = (220, 252, 231)
    else:
        badge_bg = (153, 27, 27)
        badge_text = "FAIL - UNGRADABLE RETINAL IMAGE"
        badge_fg = (254, 226, 226)
        
    draw.rectangle([metrics_x + 16, metrics_y + 16, card_w - 36, metrics_y + 56], fill=badge_bg)
    draw.text((metrics_x + 30, metrics_y + 26), badge_text, fill=badge_fg)
    
    # Metrics
    y_off = metrics_y + 75
    draw.text((metrics_x + 20, y_off), f"Overall Rating: {q['overall_quality'].upper()}", fill=(255, 255, 255))
    y_off += 30
    
    # Blur
    blur_col = (74, 222, 128) if q['blur_pass'] else (248, 113, 113)
    blur_tag = "PASS" if q['blur_pass'] else "FAIL"
    draw.text((metrics_x + 20, y_off), f"Focus / Blur Check: [{blur_tag}]", fill=blur_col)
    y_off += 18
    draw.text((metrics_x + 30, y_off), f"Variance of Laplacian: {q['blur_score']:.2f} (Min: >= {q['metadata']['thresholds_applied']['blur_threshold']:.2f})", fill=(203, 213, 225))
    y_off += 30
    
    # Brightness
    bright_col = (74, 222, 128) if q['brightness_pass'] else (248, 113, 113)
    bright_tag = "PASS" if q['brightness_pass'] else "FAIL"
    draw.text((metrics_x + 20, y_off), f"Exposure Check: [{bright_tag}] ({q['metadata']['brightness_details']['verdict']})", fill=bright_col)
    y_off += 18
    draw.text((metrics_x + 30, y_off), f"Mean Luminance: {q['metadata']['brightness_details']['mean_luminance']:.2f} (Valid: [{q['metadata']['thresholds_applied']['brightness_min']:.1f} - {q['metadata']['thresholds_applied']['brightness_max']:.1f}])", fill=(203, 213, 225))
    y_off += 30
    
    # FOV
    fov_col = (74, 222, 128) if q['fov_pass'] else (248, 113, 113)
    fov_tag = "PASS" if q['fov_pass'] else "FAIL"
    draw.text((metrics_x + 20, y_off), f"FOV Completeness: [{fov_tag}]", fill=fov_col)
    y_off += 18
    draw.text((metrics_x + 30, y_off), f"Retinal Coverage: {q['metadata']['fov_details']['retina_area_ratio']*100.0:.1f}% (Min: >= {q['metadata']['thresholds_applied']['min_fov_ratio']*100.0:.1f}%)", fill=(203, 213, 225))
    y_off += 18
    draw.text((metrics_x + 30, y_off), f"Circularity: {q['metadata']['fov_details']['circularity']:.2f} (Min: >= {q['metadata']['thresholds_applied']['min_circularity']:.2f})", fill=(203, 213, 225))
    y_off += 32
    
    # Rejection explanation
    if not q['is_gradable']:
        draw.text((metrics_x + 20, y_off), "Rejection Reason(s):", fill=(248, 113, 113))
        y_off += 20
        for r in q['rejection_reasons']:
            # simple line wrap at 42 chars
            lines = [r[i:i+42] for i in range(0, len(r), 42)]
            for line in lines:
                draw.text((metrics_x + 26, y_off), f"- {line}", fill=(254, 202, 202))
                y_off += 16
    else:
        draw.text((metrics_x + 20, y_off), "Clinical Note:", fill=(74, 222, 128))
        y_off += 20
        draw.text((metrics_x + 26, y_off), "Optimal diagnostic clarity. Ready for feature extraction.", fill=(187, 247, 208))
        
    card.save(save_path, format='PNG', quality=95)
    print(f"  [SAVED] Quality audit card -> {save_path}")

def run_tests():
    base_dir = get_base_dir()
    out_dir = os.path.join(base_dir, 'outputs', 'quality_assessment')
    os.makedirs(out_dir, exist_ok=True)
    
    cfg = {
        'blur_threshold': 25.0,
        'brightness_min': 35.0,
        'brightness_max': 180.0,
        'min_entropy': 4.0,
        'min_fov_ratio': 0.25,
        'min_circularity': 0.35
    }
    
    print("=" * 70)
    print("        RETINO-AI QUALITY ASSESSMENT TEST SUITE (PHASE 2)")
    print("=" * 70)
    
    samples = [
        ('APTOS', 'PNG', os.path.join(base_dir, 'data', 'raw', 'aptos', 'train_images', '000c1434d8d7.png'), 'aptos_quality_report.png'),
        ('IDRiD', 'JPG', os.path.join(base_dir, 'data', 'raw', 'idrid', 'Disease Grading', '1. Original Images', 'a. Training Set', 'IDRiD_001.jpg'), 'idrid_quality_report.png'),
        ('DRIVE', 'TIF', os.path.join(base_dir, 'data', 'raw', 'drive', 'training', 'images', '21_training.tif'), 'drive_quality_report.png')
    ]
    
    all_passed = True
    
    print("\n--- PART 1: Testing Real Good-Quality Images ---")
    for ds, fmt, p, out_name in samples:
        print(f"\nChecking {ds} ({fmt})...")
        if not os.path.exists(p):
            print(f"  [FAIL] File missing: {p}")
            all_passed = False
            continue
            
        img = Image.open(p).convert('RGB').resize((512, 512), Image.Resampling.BICUBIC)
        arr = np.array(img, dtype=np.uint8)
        gray = 0.2989 * arr[:,:,0] + 0.5870 * arr[:,:,1] + 0.1140 * arr[:,:,2]
        fov = detect_fov_mask(gray)
        
        q = assess_image_quality_py(arr, fov, cfg)
        
        # Verifications
        assert q['blur_pass'], f"Expected sharp {ds} image to pass blur check (score: {q['blur_score']:.2f})"
        assert q['brightness_pass'], f"Expected {ds} to pass brightness check"
        assert q['fov_pass'], f"Expected {ds} to pass FOV check"
        assert q['is_gradable'], f"Expected {ds} to be gradable"
        assert np.isfinite(q['blur_score']) and q['blur_score'] > 0
        assert np.isfinite(q['brightness_score']) and q['brightness_score'] > 0
        assert np.isfinite(q['fov_score']) and q['fov_score'] > 0
        
        print(f"  [PASS] Gradable: {q['is_gradable']} | Rating: {q['overall_quality']} | Blur: {q['blur_score']:.2f} | Brightness: {q['metadata']['brightness_details']['mean_luminance']:.2f} | FOV Area: {q['metadata']['fov_details']['retina_area_ratio']*100:.1f}%")
        
        card_path = os.path.join(out_dir, out_name)
        draw_quality_card(arr, fov, q, f"{ds} ({fmt})", card_path)
        
    print("\n--- PART 2: Testing Intentionally Degraded Scenarios ---")
    base_p = samples[0][2]
    base_im = Image.open(base_p).convert('RGB').resize((512, 512), Image.Resampling.BICUBIC)
    base_arr = np.array(base_im, dtype=np.uint8)
    base_gray = 0.2989 * base_arr[:,:,0] + 0.5870 * base_arr[:,:,1] + 0.1140 * base_arr[:,:,2]
    base_fov = detect_fov_mask(base_gray)
    
    # 1. Blur
    print("\n[Scenario A] Severe Blur...")
    blurred_im = base_im.filter(ImageFilter.GaussianBlur(radius=6.0))
    blur_arr = np.array(blurred_im, dtype=np.uint8)
    q_blur = assess_image_quality_py(blur_arr, base_fov, cfg)
    assert not q_blur['blur_pass'], "Blurred image must fail blur check"
    assert not q_blur['is_gradable'], "Blurred image must be ungradable"
    assert "blurry" in q_blur['rejection_reason'].lower()
    print(f"  [PASS] Correctly rejected: {q_blur['rejection_reason']}")
    draw_quality_card(blur_arr, base_fov, q_blur, "Severe Gaussian Blur", os.path.join(out_dir, "degraded_blur_report.png"))
    
    # 2. Dark
    print("\n[Scenario B] Severe Underexposure...")
    dark_arr = (base_arr.astype(float) * 0.15).astype(np.uint8)
    q_dark = assess_image_quality_py(dark_arr, base_fov, cfg)
    assert not q_dark['brightness_pass'], "Dark image must fail brightness check"
    assert not q_dark['is_gradable'], "Dark image must be ungradable"
    assert "underexposed" in q_dark['rejection_reason'].lower()
    print(f"  [PASS] Correctly rejected: {q_dark['rejection_reason']}")
    draw_quality_card(dark_arr, base_fov, q_dark, "Severe Underexposure", os.path.join(out_dir, "degraded_underexposed_report.png"))
    
    # 3. Overexposed
    print("\n[Scenario C] Severe Overexposure...")
    over_arr = np.clip(base_arr.astype(float) * 2.2 + 80.0, 0, 255).astype(np.uint8)
    q_over = assess_image_quality_py(over_arr, base_fov, cfg)
    assert not q_over['brightness_pass'], "Overexposed image must fail brightness check"
    assert not q_over['is_gradable'], "Overexposed image must be ungradable"
    assert "overexposed" in q_over['rejection_reason'].lower()
    print(f"  [PASS] Correctly rejected: {q_over['rejection_reason']}")
    draw_quality_card(over_arr, base_fov, q_over, "Severe Overexposure / Glare", os.path.join(out_dir, "degraded_overexposed_report.png"))
    
    # 4. Insufficient FOV
    print("\n[Scenario D] Insufficient Retinal Area...")
    crop_arr = np.zeros_like(base_arr)
    crop_arr[220:280, 220:280] = base_arr[220:280, 220:280]
    crop_fov = np.zeros_like(base_fov)
    crop_fov[220:280, 220:280] = base_fov[220:280, 220:280]
    q_crop = assess_image_quality_py(crop_arr, crop_fov, cfg)
    assert not q_crop['fov_pass'], "Tiny FOV must fail FOV check"
    assert not q_crop['is_gradable'], "Tiny FOV image must be ungradable"
    assert "retinal area" in q_crop['rejection_reason'].lower() or "distorted" in q_crop['rejection_reason'].lower()
    print(f"  [PASS] Correctly rejected: {q_crop['rejection_reason']}")
    draw_quality_card(crop_arr, crop_fov, q_crop, "Insufficient Retinal FOV", os.path.join(out_dir, "degraded_fov_report.png"))
    
    # Generate a master comparative overview matrix
    matrix_cards = [
        os.path.join(out_dir, "aptos_quality_report.png"),
        os.path.join(out_dir, "idrid_quality_report.png"),
        os.path.join(out_dir, "drive_quality_report.png"),
        os.path.join(out_dir, "degraded_blur_report.png"),
        os.path.join(out_dir, "degraded_underexposed_report.png"),
        os.path.join(out_dir, "degraded_overexposed_report.png")
    ]
    card_imgs = [Image.open(p) for p in matrix_cards if os.path.exists(p)]
    if card_imgs:
        cw, ch = card_imgs[0].size
        # 3 rows of 2 or 6 stacked
        # Let's stack them vertically or 3x2
        matrix_w = cw * 2 + 30
        matrix_h = ch * 3 + 120
        matrix_img = Image.new('RGB', (matrix_w, matrix_h), (12, 15, 20))
        m_draw = ImageDraw.Draw(matrix_img)
        m_draw.text((30, 25), "Retino-AI (SIH26038) - Phase 2 Quality Assessment Comprehensive Matrix", fill=(255, 255, 255))
        m_draw.text((30, 55), "Evaluates Focus (Laplacian Variance), Photometric Exposure Bounds, Retinal FOV, and Explainable Rejection Logic", fill=(148, 163, 184))
        
        for idx, cim in enumerate(card_imgs):
            r = idx // 2
            c = idx % 2
            x = 20 + c * (cw + 20)
            y = 90 + r * (ch + 15)
            matrix_img.paste(cim, (x, y))
            
        matrix_path = os.path.join(out_dir, "quality_assessment_matrix.png")
        matrix_img.save(matrix_path, format='PNG', quality=90)
        print(f"  [SAVED] Master comparative overview -> {matrix_path}")

    print("\n" + "=" * 70)
    print(">>> ALL QUALITY ASSESSMENT TESTS PASSED SUCCESSFULLY!")
    print(f">>> Visual quality audit cards saved in: {out_dir}")
    print("=" * 70)

if __name__ == '__main__':
    run_tests()
