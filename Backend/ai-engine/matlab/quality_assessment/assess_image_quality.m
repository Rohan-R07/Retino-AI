function quality = assess_image_quality(inputImage, customConfig)
% ASSESS_IMAGE_QUALITY Deterministic gatekeeper evaluating fundus gradability
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Audits:
%   1. BLUR / FOCUS             - Variance of Laplacian strictly within retinal FOV
%   2. BRIGHTNESS / EXPOSURE    - Mean luminance and information entropy within retinal FOV
%   3. FOV / RETINAL CONTENT    - Retinal aperture area coverage and geometric circularity
%
% Reuses FOV mask and resized image directly from preprocessed struct to avoid
% duplicating expensive operations.
%
% Usage:
%   quality = assess_image_quality(preprocessed);  % Reuses FOV from preprocess_fundus
%   quality = assess_image_quality(imagePath);     % Automatically loads & audits
%   quality = assess_image_quality(imgMatrix, cfg);
%
% Outputs:
%   quality - Struct containing at minimum:
%       .overall_quality    - Categorical rating ('excellent', 'adequate', 'poor', 'unacceptable')
%       .is_gradable        - Logical boolean (must be true to proceed to clinical inference)
%       .blur_score         - Variance of Laplacian metric
%       .brightness_score   - Photometric exposure score [0.0 to 1.0]
%       .fov_score          - FOV completeness score [0.0 to 1.0]
%       .blur_pass          - Logical flag (true if image is sharp)
%       .brightness_pass    - Logical flag (true if exposure is adequate)
%       .fov_pass           - Logical flag (true if retinal area is sufficient)
%       .rejection_reason   - Explainable clinical string detailing all failed criteria
%       .rejection_reasons  - Cell array of strings listing individual failed checks
%       .metadata           - Audit parameters, thresholds, and execution details

    % -------------------------------------------------------------
    % 1. Resolve Configuration & Thresholds
    % -------------------------------------------------------------
    if nargin < 2 || isempty(customConfig)
        try
            trainCfg = training_config();
            cfg = trainCfg.quality;
        catch
            cfg = struct();
            cfg.blur_threshold = 25.0;
            cfg.brightness_min = 35.0;
            cfg.brightness_max = 180.0;
            cfg.min_entropy = 4.0;
            cfg.min_fov_ratio = 0.25;
            cfg.min_circularity = 0.35;
        end
    else
        cfg = customConfig;
    end

    if ~isfield(cfg, 'blur_threshold'),   cfg.blur_threshold = 25.0;   end
    if ~isfield(cfg, 'brightness_min'),   cfg.brightness_min = 35.0;   end
    if ~isfield(cfg, 'brightness_max'),   cfg.brightness_max = 180.0;  end
    if ~isfield(cfg, 'min_entropy'),      cfg.min_entropy = 4.0;       end
    if ~isfield(cfg, 'min_fov_ratio'),    cfg.min_fov_ratio = 0.25;    end
    if ~isfield(cfg, 'min_circularity'),  cfg.min_circularity = 0.35;  end

    % -------------------------------------------------------------
    % 2. Extract Working Image & Retinal FOV Mask
    % -------------------------------------------------------------
    meta = struct();
    if isstruct(inputImage) && isfield(inputImage, 'resized') && isfield(inputImage, 'fov_mask')
        % Preprocessed struct passed: REUSE precomputed FOV and standardized image
        img = inputImage.resized;
        fovMask = logical(inputImage.fov_mask);
        if isfield(inputImage, 'metadata')
            meta.source_metadata = inputImage.metadata;
        end
        meta.input_type = 'preprocessed_struct';
    elseif ischar(inputImage) || isstring(inputImage)
        % File path string passed
        [img, loadMeta] = load_fundus(inputImage);
        if ndims(img) == 3
            gray = rgb2gray(img);
        else
            gray = img;
        end
        fovMask = (gray > 10);
        meta.source_metadata = loadMeta;
        meta.input_type = 'file_path';
    elseif isnumeric(inputImage) || islogical(inputImage)
        % In-memory matrix passed
        img = inputImage;
        if ndims(img) == 3
            gray = rgb2gray(img);
        else
            gray = img;
        end
        fovMask = (gray > 10);
        meta.input_type = 'image_matrix';
    else
        error('RetinoAI:InvalidInput', ...
            'Input must be a preprocessed struct, file path, or image matrix.');
    end

    meta.image_size = size(img);
    meta.thresholds_applied = cfg;
    meta.timestamp = datestr(now);

    % -------------------------------------------------------------
    % 3. Evaluate Blur / Focus
    % -------------------------------------------------------------
    [blurScore, blurPass, blurDetails] = check_blur(img, fovMask, cfg.blur_threshold);

    % -------------------------------------------------------------
    % 4. Evaluate Brightness / Illumination Adequacy
    % -------------------------------------------------------------
    [brightnessScore, brightnessPass, brightnessDetails] = check_brightness(img, fovMask, ...
        cfg.brightness_min, cfg.brightness_max, cfg.min_entropy);

    % -------------------------------------------------------------
    % 5. Evaluate FOV / Retinal Completeness
    % -------------------------------------------------------------
    [fovScore, fovPass, fovDetails] = check_fov(img, fovMask, ...
        cfg.min_fov_ratio, cfg.min_circularity);

    % -------------------------------------------------------------
    % 6. Overall Gradability Decision & Rejection Reasons
    % -------------------------------------------------------------
    isGradable = logical(blurPass && brightnessPass && fovPass);

    rejectionReasons = {};
    if ~blurPass
        rejectionReasons{end+1} = sprintf('Image too blurry (focus metric %.2f < threshold %.2f).', ...
            blurScore, cfg.blur_threshold);
    end

    if ~brightnessPass
        if brightnessDetails.is_underexposed
            rejectionReasons{end+1} = sprintf('Image severely underexposed (mean brightness %.2f < threshold %.2f).', ...
                brightnessDetails.mean_luminance, cfg.brightness_min);
        elseif brightnessDetails.is_overexposed
            rejectionReasons{end+1} = sprintf('Image severely overexposed/glare (mean brightness %.2f > threshold %.2f).', ...
                brightnessDetails.mean_luminance, cfg.brightness_max);
        else
            rejectionReasons{end+1} = sprintf('Insufficient information entropy in retinal area (%.2f < %.2f).', ...
                brightnessDetails.entropy, cfg.min_entropy);
        end
    end

    if ~fovPass
        if ~fovDetails.is_area_ok
            rejectionReasons{end+1} = sprintf('Insufficient retinal area coverage (%.1f%% of frame < threshold %.1f%%).', ...
                fovDetails.retina_area_ratio * 100.0, cfg.min_fov_ratio * 100.0);
        else
            rejectionReasons{end+1} = sprintf('Severely distorted or clipped retinal aperture (circularity %.2f < threshold %.2f).', ...
                fovDetails.circularity, cfg.min_circularity);
        end
    end

    if isGradable
        rejectionReasonCombined = '';
    else
        rejectionReasonCombined = strjoin(rejectionReasons, ' ');
    end

    % Categorical rating
    numFailures = numel(rejectionReasons);
    if isGradable
        normSharp = min(1.0, blurScore / 60.0);
        compositeIdx = (0.40 * normSharp) + (0.35 * brightnessScore) + (0.25 * fovScore);
        if compositeIdx >= 0.85
            overallQuality = 'excellent';
        else
            overallQuality = 'adequate';
        end
    else
        if numFailures >= 2
            overallQuality = 'unacceptable';
        else
            overallQuality = 'poor';
        end
    end

    % -------------------------------------------------------------
    % 7. Structured Return Result
    % -------------------------------------------------------------
    quality = struct();
    quality.overall_quality    = overallQuality;
    quality.is_gradable        = isGradable;
    quality.blur_score         = blurScore;
    quality.brightness_score   = brightnessScore;
    quality.fov_score          = fovScore;
    quality.blur_pass          = blurPass;
    quality.brightness_pass    = brightnessPass;
    quality.fov_pass           = fovPass;
    quality.rejection_reason   = rejectionReasonCombined;
    quality.rejection_reasons  = rejectionReasons;
    quality.metadata           = meta;

    % Attached detail sub-structures
    quality.sharpness_details  = blurDetails;
    quality.brightness_details = brightnessDetails;
    quality.fov_details        = fovDetails;
end
