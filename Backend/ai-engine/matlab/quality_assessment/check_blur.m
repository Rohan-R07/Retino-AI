function [sharpnessScore, isSharp, details] = check_blur(img, fovMask, threshold)
% CHECK_BLUR Evaluates retinal image focus and sharpness using gradient variance
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Method:
%   Calculates the variance of the discrete Laplacian operator strictly within
%   the retinal Field of View (FOV). Out-of-focus captures, poor optical coupling,
%   and patient motion blur produce low high-frequency gradient responses.
%
% Inputs:
%   img       - RGB or grayscale fundus image (uint8 or double)
%   fovMask   - Logical mask of the retinal FOV (optional)
%   threshold - Minimum acceptable Laplacian variance (default: from config or 25.0)
%
% Outputs:
%   sharpnessScore - Computed sharpness metric (Laplacian variance)
%   isSharp        - Logical flag (true if sharpnessScore >= threshold)
%   details        - Struct containing metric values, threshold, and audit info

    if nargin < 3 || isempty(threshold)
        try
            trainCfg = training_config();
            threshold = trainCfg.quality.blur_threshold;
        catch
            threshold = 25.0;
        end
    end

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

    % Discrete 3x3 Laplacian kernel
    lapKernel = [0 1 0; 1 -4 1; 0 1 0];
    lapResponse = imfilter(gray, lapKernel, 'replicate');

    % Compute variance specifically within the retinal FOV
    maskPixels = lapResponse(fovMask);

    if ~isempty(maskPixels) && any(fovMask(:))
        sharpnessScore = var(maskPixels);
    else
        sharpnessScore = 0.0;
    end

    isSharp = logical(sharpnessScore >= threshold);

    details = struct();
    details.blur_score = sharpnessScore;
    details.laplacian_variance = sharpnessScore;
    details.threshold = threshold;
    details.is_sharp = isSharp;
    details.metric = 'variance_of_laplacian';
    if isSharp
        details.verdict = 'sharp';
    else
        details.verdict = 'blurry';
    end
end
