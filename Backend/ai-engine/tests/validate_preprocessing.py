"""
SIH26038 - Preprocessing Pipeline Verification & Visual Generator
Validates preprocessing algorithms on real images from APTOS (PNG), IDRiD (JPG), and DRIVE (TIF).
Saves visual verification stage comparisons to outputs/preprocessing/.
"""

import os
import sys
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

def get_base_dir():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

def load_fundus(path):
    img = Image.open(path)
    if img.mode != 'RGB':
        img = img.convert('RGB')
    arr = np.array(img, dtype=np.uint8)
    return arr, {'source': path, 'original_size': arr.shape, 'format': img.format or os.path.splitext(path)[1][1:].upper()}

def otsu_thresh(gray):
    hist, _ = np.histogram(gray, bins=256, range=(0, 256))
    total = gray.size
    current_max, threshold = 0, 0
    sum_total = np.dot(np.arange(256), hist)
    sum_b, w_b = 0, 0
    for i in range(256):
        w_b += hist[i]
        if w_b == 0: continue
        w_f = total - w_b
        if w_f == 0: break
        sum_b += i * hist[i]
        m_b = sum_b / w_b
        m_f = (sum_total - sum_b) / w_f
        between_var = w_b * w_f * ((m_b - m_f) ** 2)
        if between_var > current_max:
            current_max = between_var
            threshold = i
    return threshold

def detect_retinal_fov_mask(gray_arr, threshold=None):
    H, W = gray_arr.shape
    gray_u8 = np.clip(gray_arr, 0, 255).astype(np.uint8)
    if threshold is None:
        o = otsu_thresh(gray_u8)
        threshold = max(5, min(20, round(o * 0.15)))
    
    bin_mask = (gray_u8 > threshold).astype(np.uint8)
    
    # Morphological closing (disk radius 5) via PIL Max/Min filters
    pil_mask = Image.fromarray(bin_mask * 255)
    closed = pil_mask.filter(ImageFilter.MaxFilter(size=5)).filter(ImageFilter.MinFilter(size=5))
    clean_mask = np.array(closed) > 128
    return clean_mask

def crop_fov(img_arr, padding=10):
    gray = (0.2989 * img_arr[:, :, 0] + 0.5870 * img_arr[:, :, 1] + 0.1140 * img_arr[:, :, 2]).astype(np.float32)
    fov_mask = detect_retinal_fov_mask(gray)
    
    coords = np.argwhere(fov_mask)
    if coords.size == 0:
        return img_arr, fov_mask, (0, 0, img_arr.shape[1], img_arr.shape[0])

    y0, x0 = coords.min(axis=0)
    y1, x1 = coords.max(axis=0)

    H, W = img_arr.shape[:2]
    x0 = max(0, int(x0) - padding)
    y0 = max(0, int(y0) - padding)
    x1 = min(W, int(x1) + 1 + padding)
    y1 = min(H, int(y1) + 1 + padding)

    cropped_img = img_arr[y0:y1, x0:x1]
    cropped_mask = fov_mask[y0:y1, x0:x1]
    bbox = (x0, y0, x1 - x0, y1 - y0)
    return cropped_img, cropped_mask, bbox

def resize_fundus(img_arr, target_size=(512, 512)):
    pil_img = Image.fromarray(img_arr)
    resized = pil_img.resize((target_size[1], target_size[0]), Image.Resampling.BICUBIC)
    return np.array(resized, dtype=np.uint8)

def extract_green_channel(img_arr):
    return img_arr[:, :, 1]

def normalize_illumination(img_arr, fov_mask, sigma=30):
    norm_img = np.zeros_like(img_arr, dtype=np.uint8)
    for c in range(3):
        ch = img_arr[:, :, c].astype(np.float32)
        retina_pixels = ch[fov_mask]
        if retina_pixels.size == 0:
            norm_img[:, :, c] = img_arr[:, :, c]
            continue
        mean_retina = np.mean(retina_pixels)
        
        filled = ch.copy()
        filled[~fov_mask] = mean_retina
        
        pil_filled = Image.fromarray(np.clip(filled, 0, 255).astype(np.uint8))
        blurred = pil_filled.filter(ImageFilter.GaussianBlur(radius=sigma))
        bg = np.array(blurred, dtype=np.float32)
        
        corrected = ch - bg + mean_retina
        corrected[~fov_mask] = 0
        corrected = np.clip(corrected, 0, 255).astype(np.uint8)
        norm_img[:, :, c] = corrected
    return norm_img

def compute_clahe_cdfs(channel, grid_h=8, grid_w=8, clip_limit=0.02):
    H, W = channel.shape
    tile_h = H / grid_h
    tile_w = W / grid_w
    
    cdfs = np.zeros((grid_h, grid_w, 256), dtype=np.float32)
    
    for r in range(grid_h):
        for c in range(grid_w):
            r_start = int(round(r * tile_h))
            r_end = int(round((r + 1) * tile_h))
            c_start = int(round(c * tile_w))
            c_end = int(round((c + 1) * tile_w))
            
            tile = channel[r_start:r_end, c_start:c_end]
            n_pixels = tile.size
            if n_pixels == 0:
                cdfs[r, c] = np.linspace(0, 255, 256)
                continue
                
            hist, _ = np.histogram(tile, bins=256, range=(0, 256))
            
            # Clip limit threshold
            clip_val = max(1, int(round(clip_limit * n_pixels / 256.0 * 100.0)))
            excess = np.maximum(0, hist - clip_val).sum()
            hist = np.minimum(hist, clip_val)
            hist = hist + excess // 256
            
            # Cumulative distribution function
            cdf = np.cumsum(hist).astype(np.float32)
            if cdf[-1] > 0:
                cdf = (cdf / cdf[-1]) * 255.0
            cdfs[r, c] = cdf
            
    return cdfs, tile_h, tile_w

def apply_clahe_channel(channel, grid_h=8, grid_w=8, clip_limit=0.02, fov_mask=None):
    H, W = channel.shape
    cdfs, tile_h, tile_w = compute_clahe_cdfs(channel, grid_h, grid_w, clip_limit)
    
    # Tile center coordinates
    center_y = (np.arange(grid_h) + 0.5) * tile_h
    center_x = (np.arange(grid_w) + 0.5) * tile_w
    
    # Coordinates of each pixel
    y_coords = np.arange(H)
    x_coords = np.arange(W)
    
    # Continuous tile indices
    cont_r = (y_coords / tile_h) - 0.5
    cont_c = (x_coords / tile_w) - 0.5
    
    r0 = np.clip(np.floor(cont_r).astype(int), 0, grid_h - 2)
    r1 = r0 + 1
    c0 = np.clip(np.floor(cont_c).astype(int), 0, grid_w - 2)
    c1 = c0 + 1
    
    # Interpolation weights
    dr = np.clip(cont_r - r0, 0.0, 1.0)[:, None]
    dc = np.clip(cont_c - c0, 0.0, 1.0)[None, :]
    
    r0_grid = r0[:, None]
    r1_grid = r1[:, None]
    c0_grid = c0[None, :]
    c1_grid = c1[None, :]
    
    val = channel
    
    # Evaluate the 4 CDFs
    t00 = cdfs[r0_grid, c0_grid, val]
    t01 = cdfs[r0_grid, c1_grid, val]
    t10 = cdfs[r1_grid, c0_grid, val]
    t11 = cdfs[r1_grid, c1_grid, val]
    
    # Bilinear interpolation
    top = (1.0 - dc) * t00 + dc * t01
    bot = (1.0 - dc) * t10 + dc * t11
    enhanced = (1.0 - dr) * top + dr * bot
    
    if fov_mask is not None:
        enhanced[~fov_mask] = 0
        
    return np.clip(enhanced, 0, 255).astype(np.uint8)

def apply_clahe(img_arr, clip_limit=0.02, grid_size=(8, 8), fov_mask=None):
    if img_arr.ndim == 3 and img_arr.shape[2] == 3:
        # CIE L*a*b* space enhancement (approx via luminance scaling to keep exact color balance)
        r = img_arr[:, :, 0].astype(np.float32)
        g = img_arr[:, :, 1].astype(np.float32)
        b = img_arr[:, :, 2].astype(np.float32)
        
        # Luminance
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        lum_u8 = np.clip(lum, 0, 255).astype(np.uint8)
        
        enhanced_lum = apply_clahe_channel(lum_u8, grid_size[0], grid_size[1], clip_limit, fov_mask).astype(np.float32)
        
        ratio = (enhanced_lum + 1.0) / (lum + 1.0)
        
        enhanced_r = np.clip(r * ratio, 0, 255)
        enhanced_g = np.clip(g * ratio, 0, 255)
        enhanced_b = np.clip(b * ratio, 0, 255)
        
        out = np.stack([enhanced_r, enhanced_g, enhanced_b], axis=2).astype(np.uint8)
        if fov_mask is not None:
            for c in range(3):
                out[:, :, c][~fov_mask] = 0
        return out
    else:
        return apply_clahe_channel(img_arr, grid_size[0], grid_size[1], clip_limit, fov_mask)

def denoise_image(img_arr):
    pil_img = Image.fromarray(img_arr)
    denoised = pil_img.filter(ImageFilter.MedianFilter(size=3))
    return np.array(denoised, dtype=np.uint8)

def draw_stage_card(img_arr, title, subtitle="", size=(380, 380)):
    pil_sub = Image.fromarray(img_arr)
    pil_sub = pil_sub.resize(size, Image.Resampling.BICUBIC)
    
    header_h = 50
    card = Image.new('RGB', (size[0], size[1] + header_h), (24, 28, 36))
    draw = ImageDraw.Draw(card)
    
    draw.text((12, 8), title, fill=(255, 255, 255))
    if subtitle:
        draw.text((12, 28), subtitle, fill=(160, 180, 200))
    
    card.paste(pil_sub, (0, header_h))
    return card

def create_stages_montage(stages, dataset_name, fmt, save_path):
    card_size = (360, 360)
    cards = [draw_stage_card(s[0], s[1], s[2], size=card_size) for s in stages]
    
    w_card = card_size[0]
    h_card = card_size[1] + 50
    gap = 14
    margin_top = 70
    margin_side = 20
    
    total_w = margin_side * 2 + 3 * w_card + 2 * gap
    total_h = margin_top + 2 * h_card + gap + 20
    
    montage = Image.new('RGB', (total_w, total_h), (15, 18, 24))
    draw = ImageDraw.Draw(montage)
    
    draw.text((margin_side, 18), f"Retino-AI Preprocessing Pipeline - {dataset_name} ({fmt})", fill=(255, 255, 255))
    draw.text((margin_side, 42), f"Project: SIH26038 | Stages: Original -> Crop -> Resize -> Green -> Normalized -> Enhanced", fill=(140, 160, 180))
    
    for idx, card in enumerate(cards):
        row = idx // 3
        col = idx % 3
        x = margin_side + col * (w_card + gap)
        y = margin_top + row * (h_card + gap)
        montage.paste(card, (x, y))
        
    montage.save(save_path, format='PNG', quality=95)
    print(f"  [SAVED] Visual verification montage -> {save_path}")

def run_tests():
    base_dir = get_base_dir()
    out_dir = os.path.join(base_dir, 'outputs', 'preprocessing')
    os.makedirs(out_dir, exist_ok=True)
    
    samples = [
        {
            'dataset': 'APTOS',
            'format': 'PNG',
            'path': os.path.join(base_dir, 'data', 'raw', 'aptos', 'train_images', '000c1434d8d7.png'),
            'out_name': 'aptos_stages.png'
        },
        {
            'dataset': 'IDRiD',
            'format': 'JPG',
            'path': os.path.join(base_dir, 'data', 'raw', 'idrid', 'Disease Grading', '1. Original Images', 'a. Training Set', 'IDRiD_001.jpg'),
            'out_name': 'idrid_stages.png'
        },
        {
            'dataset': 'DRIVE',
            'format': 'TIF',
            'path': os.path.join(base_dir, 'data', 'raw', 'drive', 'training', 'images', '21_training.tif'),
            'out_name': 'drive_stages.png'
        }
    ]
    
    print("=" * 70)
    print("      RETINO-AI FUNDUS PREPROCESSING PIPELINE TEST RUNNER")
    print("=" * 70)
    
    all_passed = True
    
    for s in samples:
        ds = s['dataset']
        fmt = s['format']
        path = s['path']
        print(f"\n--- Testing Dataset: {ds} ({fmt}) ---")
        print(f"Target file: {path}")
        
        if not os.path.exists(path):
            print(f"  [FAIL] File not found: {path}")
            all_passed = False
            continue
            
        # 1. Load Fundus Image
        orig, meta = load_fundus(path)
        print(f"  [PASS] 1. Load Image: {orig.shape} uint8 (Format: {meta['format']})")
        assert orig.ndim == 3 and orig.shape[2] == 3, "Image must be 3-channel RGB"
        assert orig.size > 0, "Image cannot be empty"
        assert np.isfinite(orig).all(), "Image must contain finite values"
        
        # 2. Retinal FOV Cropping
        cropped, crop_mask, bbox = crop_fov(orig, padding=10)
        print(f"  [PASS] 2. FOV Crop: {cropped.shape} uint8 (bbox: {bbox})")
        assert cropped.shape[0] <= orig.shape[0] and cropped.shape[1] <= orig.shape[1]
        assert cropped.size > 0
        
        # 3. Standardized Resize
        target_size = (512, 512)
        resized = resize_fundus(cropped, target_size=target_size)
        pil_mask = Image.fromarray((crop_mask.astype(np.uint8) * 255))
        resized_mask = np.array(pil_mask.resize((512, 512), Image.Resampling.NEAREST)) > 100
        print(f"  [PASS] 3. Standardized Resize: {resized.shape} uint8")
        assert resized.shape == (512, 512, 3)
        assert np.isfinite(resized).all()
        
        # 4. Green Channel Extraction
        green_ch = extract_green_channel(resized)
        print(f"  [PASS] 4. Green Channel Extraction: {green_ch.shape} uint8")
        assert green_ch.shape == (512, 512)
        assert green_ch.dtype == np.uint8
        
        # 5. Illumination Normalization
        norm_img = normalize_illumination(resized, resized_mask, sigma=30)
        print(f"  [PASS] 5. Illumination Normalization: {norm_img.shape} uint8 (Range: [{norm_img.min()}, {norm_img.max()}])")
        assert norm_img.shape == (512, 512, 3)
        assert np.isfinite(norm_img).all()
        assert norm_img.max() > 0
        
        # 6. Contrast Enhancement (CLAHE with bilinear tile interpolation)
        enhanced_img = apply_clahe(norm_img, clip_limit=0.02, grid_size=(8, 8), fov_mask=resized_mask)
        enhanced_green = apply_clahe(green_ch, clip_limit=0.02, grid_size=(8, 8), fov_mask=resized_mask)
        print(f"  [PASS] 6. Contrast Enhancement: {enhanced_img.shape} uint8 (Range: [{enhanced_img.min()}, {enhanced_img.max()}])")
        assert enhanced_img.shape == (512, 512, 3)
        assert enhanced_green.shape == (512, 512)
        assert np.isfinite(enhanced_img).all()
        
        # 7. Denoising
        denoised_green = denoise_image(enhanced_green)
        print(f"  [PASS] 7. Lightweight Denoising: {denoised_green.shape} uint8")
        assert denoised_green.shape == (512, 512)
        assert np.isfinite(denoised_green).all()
        
        # 8. Visual Stages Assembly
        green_disp = np.stack([green_ch, green_ch, green_ch], axis=2)
        stages = [
            (orig, "1. Original Raw Image", f"Format: {fmt} | Shape: {orig.shape[1]}x{orig.shape[0]}"),
            (cropped, "2. Retinal FOV Crop", f"BBox: {bbox[0]},{bbox[1]},{bbox[2]},{bbox[3]} (+10px pad)"),
            (resized, "3. Resized Prototype", f"Standardized: 512x512 RGB"),
            (green_disp, "4. Green Channel", "Optimal vessel/lesion contrast"),
            (norm_img, "5. Illumination Normalized", "Graham background subtraction"),
            (enhanced_img, "6. Contrast Enhanced", "CLAHE (Bilinear Tile Interpolation)")
        ]
        
        out_save_path = os.path.join(out_dir, s['out_name'])
        create_stages_montage(stages, ds, fmt, out_save_path)
        
    print("\n" + "=" * 70)
    if all_passed:
        print(">>> ALL 3 FORMATS (PNG, JPG, TIF) PASSED VERIFICATION & PROCESSED!")
        print(f">>> Visual artifacts saved in: {out_dir}")
    else:
        print(">>> SOME VERIFICATIONS FAILED.")
    print("=" * 70)

if __name__ == '__main__':
    run_tests()
