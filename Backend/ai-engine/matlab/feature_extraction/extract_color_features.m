function colorFeats = extract_color_features(img, fovMask)
% EXTRACT_COLOR_FEATURES Extracts fundamental photometric and color statistics
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Features Extracted (strictly within retinal FOV):
%   1. mean_red        - Mean red-channel intensity
%   2. mean_green      - Mean green-channel intensity
%   3. mean_blue       - Mean blue-channel intensity
%   4. std_red         - Standard deviation of red channel
%   5. std_green       - Standard deviation of green channel
%   6. std_blue        - Standard deviation of blue channel
%   7. green_mean      - Dedicated green channel mean intensity
%   8. green_contrast  - Standard deviation (contrast) of the green channel
%
% Inputs:
%   img      - uint8 RGB image [H x W x 3]
%   fovMask  - Logical mask of the retinal FOV [H x W]
%
% Output:
%   colorFeats - Struct containing the 8 color scalar descriptors

    if nargin < 2 || isempty(fovMask)
        if ndims(img) == 3
            gray = rgb2gray(img);
        else
            gray = img;
        end
        fovMask = (gray > 10);
    else
        fovMask = logical(fovMask);
    end

    colorFeats = struct();

    if ndims(img) ~= 3 || size(img, 3) < 3
        % Fallback for grayscale
        grayData = double(img);
        px = grayData(fovMask);
        if isempty(px)
            mVal = 0.0; sVal = 0.0;
        else
            mVal = mean(px); sVal = std(px);
        end
        colorFeats.mean_red = mVal;
        colorFeats.mean_green = mVal;
        colorFeats.mean_blue = mVal;
        colorFeats.std_red = sVal;
        colorFeats.std_green = sVal;
        colorFeats.std_blue = sVal;
        colorFeats.green_mean = mVal;
        colorFeats.green_contrast = sVal;
        return;
    end

    rCh = double(img(:, :, 1));
    gCh = double(img(:, :, 2));
    bCh = double(img(:, :, 3));

    rPx = rCh(fovMask);
    gPx = gCh(fovMask);
    bPx = bCh(fovMask);

    if ~isempty(rPx)
        colorFeats.mean_red        = mean(rPx);
        colorFeats.mean_green      = mean(gPx);
        colorFeats.mean_blue       = mean(bPx);
        colorFeats.std_red         = std(rPx);
        colorFeats.std_green       = std(gPx);
        colorFeats.std_blue        = std(bPx);
        colorFeats.green_mean      = mean(gPx);
        colorFeats.green_contrast  = std(gPx);
    else
        colorFeats.mean_red        = 0.0;
        colorFeats.mean_green      = 0.0;
        colorFeats.mean_blue       = 0.0;
        colorFeats.std_red         = 0.0;
        colorFeats.std_green       = 0.0;
        colorFeats.std_blue        = 0.0;
        colorFeats.green_mean      = 0.0;
        colorFeats.green_contrast  = 0.0;
    end
end
