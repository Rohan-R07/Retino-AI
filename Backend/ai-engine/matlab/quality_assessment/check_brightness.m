function [brightnessScore, isAdequate, details] = check_brightness(img, fovMask, minMean, maxMean, minEntropy)
% CHECK_BRIGHTNESS Evaluates illumination adequacy and entropy strictly inside retinal FOV
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Objectives:
%   - Rejects severe underexposure (poor flash, small pupil, cataracts)
%   - Rejects severe overexposure / flash glare (washed out retinal vessels)
%   - Evaluates brightness strictly inside retinal FOV, ignoring camera black borders
%   - Verifies information entropy across pixel intensities
%
% Inputs:
%   img        - RGB or grayscale image
%   fovMask    - Logical mask of retinal FOV
%   minMean    - Minimum acceptable mean luminance (default: from config or 35.0)
%   maxMean    - Maximum acceptable mean luminance (default: from config or 180.0)
%   minEntropy - Minimum acceptable Shannon entropy (default: from config or 4.0)
%
% Outputs:
%   brightnessScore - Normalized exposure quality score [0.0 to 1.0]
%   isAdequate      - Logical flag (true if image is adequately illuminated)
%   details         - Struct containing detailed photometric metrics

    % Resolve configurable thresholds
    try
        trainCfg = training_config();
        defMinMean = trainCfg.quality.brightness_min;
        defMaxMean = trainCfg.quality.brightness_max;
        defMinEntropy = trainCfg.quality.min_entropy;
    catch
        defMinMean = 35.0;
        defMaxMean = 180.0;
        defMinEntropy = 4.0;
    end

    if nargin < 3 || isempty(minMean),    minMean = defMinMean;       end
    if nargin < 4 || isempty(maxMean),    maxMean = defMaxMean;       end
    if nargin < 5 || isempty(minEntropy), minEntropy = defMinEntropy; end

    if ndims(img) == 3
        gray = double(rgb2gray(img));
    else
        gray = double(img);
    end

    if nargin < 2 || isempty(fovMask)
        fovMask = (gray > 10);
    else
        fovMask = logical(fovMask);
    end

    retinaPixels = gray(fovMask);

    if ~isempty(retinaPixels) && any(fovMask(:))
        meanVal = mean(retinaPixels);
        % Shannon entropy of luminance inside retinal FOV
        h = histcounts(uint8(retinaPixels), 0:256, 'Normalization', 'probability');
        h = h(h > 0);
        entropyVal = -sum(h .* log2(h));
    else
        meanVal = 0.0;
        entropyVal = 0.0;
    end

    isUnderexposed = (meanVal < minMean);
    isOverexposed = (meanVal > maxMean);
    isLowEntropy = (entropyVal < minEntropy);

    isAdequate = logical(~isUnderexposed && ~isOverexposed && ~isLowEntropy);

    % Normalized exposure score [0 to 1]
    if meanVal < minMean
        brightnessScore = max(0.0, meanVal / minMean);
    elseif meanVal > maxMean
        brightnessScore = max(0.0, 1.0 - ((meanVal - maxMean) / (255.0 - maxMean)));
    else
        brightnessScore = 1.0;
    end

    % Factor in entropy
    if entropyVal < minEntropy
        brightnessScore = brightnessScore * max(0.2, entropyVal / minEntropy);
    end

    verdict = 'adequate';
    if isUnderexposed
        verdict = 'underexposed';
    elseif isOverexposed
        verdict = 'overexposed';
    elseif isLowEntropy
        verdict = 'low_entropy';
    end

    details = struct();
    details.mean_luminance = meanVal;
    details.entropy = entropyVal;
    details.min_mean_threshold = minMean;
    details.max_mean_threshold = maxMean;
    details.min_entropy_threshold = minEntropy;
    details.is_adequate = isAdequate;
    details.is_underexposed = isUnderexposed;
    details.is_overexposed = isOverexposed;
    details.verdict = verdict;
end
