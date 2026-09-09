function enhancedImg = enhance_contrast(img, method, clipLimit, numTiles, distribution, fovMask)
% ENHANCE_CONTRAST Performs localized contrast enhancement on fundus images via CLAHE
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Methods:
%   'clahe'  - Contrast-Limited Adaptive Histogram Equalization (default)
%              Applied in CIE L*a*b* space (L* channel) for RGB, or directly for single channels.
%   'histeq' - Global histogram equalization
%
% Inputs:
%   img          - uint8 RGB or single-channel green image
%   method       - 'clahe' (default) or 'histeq'
%   clipLimit    - Contrast limit threshold in [0, 1] (default: 0.02)
%   numTiles     - Number of contextual grid tiles [rows, cols] (default: [8, 8])
%   distribution - Desired histogram distribution: 'rayleigh' (default), 'uniform', 'exponential'
%   fovMask      - Binary mask of the retina (optional, suppresses background noise)
%
% Output:
%   enhancedImg - Contrast-enhanced image (uint8)

    if nargin < 2 || isempty(method),       method = 'clahe'; end
    if nargin < 3 || isempty(clipLimit),    clipLimit = 0.02; end
    if nargin < 4 || isempty(numTiles),     numTiles = [8, 8]; end
    if nargin < 5 || isempty(distribution), distribution = 'rayleigh'; end
    if nargin < 6,                          fovMask = []; end

    isRGB = (ndims(img) == 3 && size(img, 3) == 3);

    switch lower(method)
        case 'clahe'
            if isRGB
                % Enhance L* luminance channel in CIE L*a*b* space to preserve color balance
                lab = rgb2lab(img);
                L = lab(:, :, 1) / 100.0;
                L_enhanced = adapthisteq(L, 'ClipLimit', clipLimit, ...
                    'NumTiles', numTiles, 'Distribution', distribution);
                lab(:, :, 1) = L_enhanced * 100.0;
                enhancedImg = lab2rgb(lab, 'OutputType', 'uint8');
            else
                % Single-channel (e.g. green channel)
                enhancedImg = adapthisteq(img, 'ClipLimit', clipLimit, ...
                    'NumTiles', numTiles, 'Distribution', distribution);
            end

        case 'histeq'
            if isRGB
                enhancedImg = zeros(size(img), 'like', img);
                for c = 1:3
                    enhancedImg(:, :, c) = histeq(img(:, :, c));
                end
            else
                enhancedImg = histeq(img);
            end

        otherwise
            enhancedImg = img;
    end

    % If FOV mask provided, ensure background remains clean black
    if ~isempty(fovMask)
        if isRGB
            for c = 1:3
                ch = enhancedImg(:, :, c);
                ch(~fovMask) = 0;
                enhancedImg(:, :, c) = ch;
            end
        else
            enhancedImg(~fovMask) = 0;
        end
    end
end
