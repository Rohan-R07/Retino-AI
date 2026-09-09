function textureFeats = extract_texture_features(greenCh, fovMask, numLevels, offsets)
% EXTRACT_TEXTURE_FEATURES Computes Haralick GLCM texture metrics on retinal green channel
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Features Extracted:
%   1. glcm_contrast    - Local intensity variation in microvascular tissue
%   2. glcm_correlation - Linear dependency of gray levels across neighbouring pixels
%   3. glcm_energy      - Uniformity and order of the retinal texture
%   4. glcm_homogeneity - Closeness of element distribution to diagonal
%
% Inputs:
%   greenCh   - uint8 green-channel matrix [H x W]
%   fovMask   - Logical mask of the retinal FOV [H x W]
%   numLevels - Quantization levels for GLCM (default: from config or 16)
%   offsets   - Directional pixel offsets for GLCM (default: standard 4 directions)
%
% Output:
%   textureFeats - Struct containing the 4 GLCM texture descriptors

    try
        trainCfg = training_config();
        defNumLevels = trainCfg.features.glcm_num_levels;
        defOffsets = trainCfg.features.texture_glcm_offsets;
    catch
        defNumLevels = 16;
        defOffsets = [0 1; -1 1; -1 0; -1 -1];
    end

    if nargin < 3 || isempty(numLevels), numLevels = defNumLevels; end
    if nargin < 4 || isempty(offsets),   offsets = defOffsets;     end

    if nargin < 2 || isempty(fovMask)
        fovMask = (greenCh > 10);
    else
        fovMask = logical(fovMask);
    end

    textureFeats = struct();

    % Zero out non-retinal background outside FOV
    maskedGreen = greenCh;
    maskedGreen(~fovMask) = 0;

    % Scale green channel to quantized levels for stable, robust GLCM statistics
    try
        glcm = graycomatrix(maskedGreen, 'NumLevels', numLevels, 'Offset', offsets, 'GrayLimits', [0 255]);
        stats = graycoprops(glcm, {'Contrast', 'Correlation', 'Energy', 'Homogeneity'});

        textureFeats.glcm_contrast    = mean(stats.Contrast);
        textureFeats.glcm_correlation = mean(stats.Correlation);
        textureFeats.glcm_energy      = mean(stats.Energy);
        textureFeats.glcm_homogeneity = mean(stats.Homogeneity);
    catch
        textureFeats.glcm_contrast    = 0.0;
        textureFeats.glcm_correlation = 0.0;
        textureFeats.glcm_energy      = 0.0;
        textureFeats.glcm_homogeneity = 0.0;
    end
end
