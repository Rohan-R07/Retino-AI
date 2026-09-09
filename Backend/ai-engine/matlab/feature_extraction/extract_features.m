function features = extract_features(preprocessedInput, optionalMasks, cfg)
% EXTRACT_FEATURES Master feature extraction pipeline combining clinical retinal biomarkers
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Architecture:
%   Produces a standardized, deterministic 22-dimensional numerical feature vector:
%     1. Color Features (8)   - mean RGB, std RGB, green_mean, green_contrast
%     2. Texture Features (4) - GLCM contrast, correlation, energy, homogeneity
%     3. Vessel Features (2)  - vessel_density, vessel_edge_density (DRIVE masks)
%     4. Lesion Features (8)  - MA, HE, EX, SE areas and counts (IDRiD masks)
%
% Usage:
%   features = extract_features(preprocessed);
%   features = extract_features(preprocessed, optionalMasks);
%   features = extract_features(imagePath, optionalMasks, cfg);
%
% Outputs:
%   features - Struct containing:
%       .color        - Struct with 8 color scalar descriptors
%       .texture      - Struct with 4 GLCM texture descriptors
%       .vessel       - Struct with 2 vascular morphological descriptors
%       .lesion       - Struct with 8 pathological lesion descriptors
%       .vector       - 1x22 numeric array (no NaN / Inf)
%       .names        - 1x22 cell array of feature labels
%       .num_features - Integer scalar (22)
%       .table        - 1-row table ready for ML classification

    if nargin < 2
        optionalMasks = struct();
    end

    if nargin < 3 || isempty(cfg)
        try
            trainCfg = training_config();
            cfg = trainCfg.features;
        catch
            cfg = struct();
            cfg.glcm_num_levels = 16;
            cfg.texture_glcm_offsets = [0 1; -1 1; -1 0; -1 -1];
        end
    end

    if ~isfield(cfg, 'glcm_num_levels'), cfg.glcm_num_levels = 16; end
    if ~isfield(cfg, 'texture_glcm_offsets'), cfg.texture_glcm_offsets = [0 1; -1 1; -1 0; -1 -1]; end

    % -------------------------------------------------------------
    % 1. Ingest Preprocessed Fundus & Working Channels
    % -------------------------------------------------------------
    if isstruct(preprocessedInput) && isfield(preprocessedInput, 'resized')
        img = preprocessedInput.resized;
        greenCh = preprocessedInput.green_channel;
        fovMask = logical(preprocessedInput.fov_mask);
    elseif ischar(preprocessedInput) || isstring(preprocessedInput)
        prep = preprocess_fundus(preprocessedInput);
        img = prep.resized;
        greenCh = prep.green_channel;
        fovMask = logical(prep.fov_mask);
    elseif isnumeric(preprocessedInput) || islogical(preprocessedInput)
        img = preprocessedInput;
        if ndims(img) == 3 && size(img, 3) >= 2
            greenCh = img(:, :, 2);
            gray = rgb2gray(img);
        else
            greenCh = img;
            gray = img;
        end
        fovMask = (gray > 10);
    else
        error('RetinoAI:InvalidInput', ...
            'Input must be a preprocessed struct, file path, or image matrix.');
    end

    % -------------------------------------------------------------
    % 2. Extract Color Features (8)
    % -------------------------------------------------------------
    colorFeats = extract_color_features(img, fovMask);

    % -------------------------------------------------------------
    % 3. Extract Texture Features (4)
    % -------------------------------------------------------------
    textureFeats = extract_texture_features(greenCh, fovMask, ...
        cfg.glcm_num_levels, cfg.texture_glcm_offsets);

    % -------------------------------------------------------------
    % 4. Extract Vessel Features (2)
    % -------------------------------------------------------------
    vesselMask = [];
    if isstruct(optionalMasks)
        if isfield(optionalMasks, 'vessel_mask') && ~isempty(optionalMasks.vessel_mask)
            vesselMask = optionalMasks.vessel_mask;
        elseif isfield(optionalMasks, 'vessels') && ~isempty(optionalMasks.vessels)
            vesselMask = optionalMasks.vessels;
        end
    end
    vesselFeats = extract_vessel_features(vesselMask, fovMask);

    % -------------------------------------------------------------
    % 5. Extract Lesion Features (8)
    % -------------------------------------------------------------
    lesionFeats = extract_lesion_features(optionalMasks, fovMask);

    % -------------------------------------------------------------
    % 6. Assemble Standardized Feature Vector & Names
    % -------------------------------------------------------------
    featureNames = { ...
        'mean_red', 'mean_green', 'mean_blue', ...
        'std_red', 'std_green', 'std_blue', ...
        'green_mean', 'green_contrast', ...
        'glcm_contrast', 'glcm_correlation', 'glcm_energy', 'glcm_homogeneity', ...
        'vessel_density', 'vessel_edge_density', ...
        'microaneurysm_area', 'microaneurysm_count', ...
        'hemorrhage_area', 'hemorrhage_count', ...
        'hard_exudate_area', 'hard_exudate_count', ...
        'soft_exudate_area', 'soft_exudate_count' ...
    };

    featureVector = [ ...
        colorFeats.mean_red, colorFeats.mean_green, colorFeats.mean_blue, ...
        colorFeats.std_red, colorFeats.std_green, colorFeats.std_blue, ...
        colorFeats.green_mean, colorFeats.green_contrast, ...
        textureFeats.glcm_contrast, textureFeats.glcm_correlation, ...
        textureFeats.glcm_energy, textureFeats.glcm_homogeneity, ...
        vesselFeats.vessel_density, vesselFeats.vessel_edge_density, ...
        lesionFeats.microaneurysm_area, lesionFeats.microaneurysm_count, ...
        lesionFeats.hemorrhage_area, lesionFeats.hemorrhage_count, ...
        lesionFeats.hard_exudate_area, lesionFeats.hard_exudate_count, ...
        lesionFeats.soft_exudate_area, lesionFeats.soft_exudate_count ...
    ];

    % Ensure purely double precision and finite values
    featureVector = double(featureVector);
    featureVector(~isfinite(featureVector)) = 0.0;

    % -------------------------------------------------------------
    % 7. Return Structured Object
    % -------------------------------------------------------------
    features = struct();
    features.color        = colorFeats;
    features.texture      = textureFeats;
    features.vessel       = vesselFeats;
    features.lesion       = lesionFeats;
    features.vector       = featureVector;
    features.names        = featureNames;
    features.num_features = numel(featureVector);

    try
        features.table = array2table(featureVector, 'VariableNames', featureNames);
    catch
        features.table = [];
    end
end
