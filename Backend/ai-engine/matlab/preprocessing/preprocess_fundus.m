function processed = preprocess_fundus(inputImage, cfg)
% PREPROCESS_FUNDUS Unified, classical image processing pipeline for retinal fundus images
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Pipeline Stages:
%   1. LOAD FUNDUS IMAGE       - Supports PNG (APTOS), JPG (IDRiD), TIF (DRIVE), DICOM
%   2. RETINAL FOV CROPPING    - Detects circular retinal aperture with safety padding
%   3. STANDARDIZED RESIZING   - Configurable dimensions (default: 512x512 via training_config)
%   4. GREEN CHANNEL           - Extracted for optimal lesion & vascular contrast
%   5. ILLUMINATION NORM       - Classical background estimation (Graham model)
%   6. CONTRAST ENHANCEMENT    - Localized CLAHE in L*a*b* space & green channel
%   7. LIGHTWEIGHT DENOISING   - 3x3 median filter preserving microaneurysm boundaries
%
% Usage:
%   processed = preprocess_fundus('data/raw/aptos/train_images/000c1434d8d7.png');
%   processed = preprocess_fundus(rawImgMatrix);
%   processed = preprocess_fundus(rawImgMatrix, customConfig);
%
% Output:
%   processed - Struct containing at minimum:
%       .original      - Raw standardized RGB image
%       .cropped       - Tightly cropped retinal image (black border removed)
%       .resized       - Resized RGB image [targetSize x targetSize x 3]
%       .green_channel - Extracted green channel [targetSize x targetSize]
%       .normalized    - Illumination-normalized RGB image
%       .enhanced      - Contrast-enhanced (CLAHE) RGB image
%       .enhanced_green- Contrast-enhanced green channel
%       .denoised      - Lightweight edge-preserving denoised green channel
%       .fov_mask      - Binary mask of the retinal FOV
%       .metadata      - Struct recording parameters, sizes, and execution info

    % Resolve configuration
    if nargin < 2 || isempty(cfg)
        try
            trainCfg = training_config();
            cfg = trainCfg.preprocessing;
            cfg.target_size = trainCfg.image.target_size;
        catch
            cfg = struct();
            cfg.target_size = [512, 512];
            cfg.enable_fov_crop = true;
            cfg.fov_padding = 10;
            cfg.enable_illumination_norm = true;
            cfg.illumination_sigma = 30;
            cfg.illumination_method = 'subtraction';
            cfg.enable_clahe = true;
            cfg.clahe_clip_limit = 0.02;
            cfg.clahe_distribution = 'rayleigh';
            cfg.enable_denoising = true;
            cfg.denoise_method = 'median';
            cfg.denoise_kernel = [3, 3];
        end
    end

    % Ensure all fields exist with robust fallbacks
    if ~isfield(cfg, 'target_size'),             cfg.target_size = [512, 512]; end
    if ~isfield(cfg, 'enable_fov_crop'),         cfg.enable_fov_crop = true; end
    if ~isfield(cfg, 'fov_padding'),             cfg.fov_padding = 10; end
    if ~isfield(cfg, 'enable_illumination_norm'), cfg.enable_illumination_norm = true; end
    if ~isfield(cfg, 'illumination_sigma'),      cfg.illumination_sigma = 30; end
    if ~isfield(cfg, 'illumination_method'),     cfg.illumination_method = 'subtraction'; end
    if ~isfield(cfg, 'enable_clahe'),             cfg.enable_clahe = true; end
    if ~isfield(cfg, 'clahe_clip_limit'),        cfg.clahe_clip_limit = 0.02; end
    if ~isfield(cfg, 'clahe_distribution'),      cfg.clahe_distribution = 'rayleigh'; end
    if ~isfield(cfg, 'clahe_num_tiles'),         cfg.clahe_num_tiles = [8, 8]; end
    if ~isfield(cfg, 'enable_denoising'),        cfg.enable_denoising = true; end
    if ~isfield(cfg, 'denoise_method'),          cfg.denoise_method = 'median'; end
    if ~isfield(cfg, 'denoise_kernel'),          cfg.denoise_kernel = [3, 3]; end

    % -------------------------------------------------------------
    % Stage 1: Load Fundus Image
    % -------------------------------------------------------------
    [origImg, loadMeta] = load_fundus(inputImage);

    % -------------------------------------------------------------
    % Stage 2: Retinal FOV Cropping
    % -------------------------------------------------------------
    if cfg.enable_fov_crop
        [croppedImg, fovMaskCropped, bbox] = crop_fov(origImg, [], cfg.fov_padding);
    else
        croppedImg = origImg;
        if ndims(origImg) == 3
            fovMaskCropped = (rgb2gray(origImg) > 10);
        else
            fovMaskCropped = (origImg > 10);
        end
        bbox = [1, 1, size(origImg, 2), size(origImg, 1)];
    end

    % -------------------------------------------------------------
    % Stage 3: Resizing to Prototype Dimensions
    % -------------------------------------------------------------
    [resizedImg, scaleInfo] = resize_fundus(croppedImg, cfg.target_size);
    fovMaskResized = imresize(fovMaskCropped, cfg.target_size, 'nearest');

    % -------------------------------------------------------------
    % Stage 4: Green Channel Extraction
    % -------------------------------------------------------------
    greenCh = extract_green_channel(resizedImg);

    % -------------------------------------------------------------
    % Stage 5: Illumination Normalization
    % -------------------------------------------------------------
    if cfg.enable_illumination_norm
        normImg = normalize_illumination(resizedImg, cfg.illumination_method, ...
            cfg.illumination_sigma, fovMaskResized);
        normGreen = extract_green_channel(normImg);
    else
        normImg = resizedImg;
        normGreen = greenCh;
    end

    % -------------------------------------------------------------
    % Stage 6: Contrast Enhancement (CLAHE)
    % -------------------------------------------------------------
    if cfg.enable_clahe
        enhancedImg = enhance_contrast(normImg, 'clahe', cfg.clahe_clip_limit, ...
            cfg.clahe_num_tiles, cfg.clahe_distribution, fovMaskResized);
        enhancedGreen = enhance_contrast(normGreen, 'clahe', cfg.clahe_clip_limit, ...
            cfg.clahe_num_tiles, cfg.clahe_distribution, fovMaskResized);
    else
        enhancedImg = normImg;
        enhancedGreen = normGreen;
    end

    % -------------------------------------------------------------
    % Stage 7: Lightweight Denoising
    % -------------------------------------------------------------
    if cfg.enable_denoising
        denoisedGreen = denoise_fundus(enhancedGreen, cfg.denoise_method, cfg.denoise_kernel);
    else
        denoisedGreen = enhancedGreen;
    end

    % -------------------------------------------------------------
    % Stage 8: Structured Return Object
    % -------------------------------------------------------------
    processed = struct();
    processed.original       = origImg;
    processed.cropped        = croppedImg;
    processed.resized        = resizedImg;
    processed.green_channel  = greenCh;
    processed.normalized     = normImg;
    processed.enhanced       = enhancedImg;
    processed.enhanced_green = enhancedGreen;
    processed.denoised       = denoisedGreen;
    processed.fov_mask       = fovMaskResized;

    % Metadata
    processed.metadata = loadMeta;
    processed.metadata.target_size = cfg.target_size;
    processed.metadata.crop_bbox = bbox;
    processed.metadata.scale_info = scaleInfo;
    processed.metadata.config_applied = cfg;
    processed.metadata.pipeline_version = '1.0.0';
    processed.metadata.timestamp = datestr(now);
end
