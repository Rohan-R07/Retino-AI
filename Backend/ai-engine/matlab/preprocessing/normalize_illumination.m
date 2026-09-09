function normImg = normalize_illumination(img, method, sigma, fovMask)
% NORMALIZE_ILLUMINATION Corrects non-uniform lighting across retinal regions
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Method:
%   Classical background estimation and correction (Graham / Foracchia model).
%   Estimates slow illumination field variation using a large Gaussian filter (sigma ~ 30).
%   Fills non-retinal background with the local mean prior to filtering to eliminate boundary halo artifacts.
%
% Inputs:
%   img     - uint8 RGB or grayscale/green image
%   method  - 'subtraction' (default) or 'division'
%   sigma   - Standard deviation of Gaussian illumination filter (default: 30)
%   fovMask - Binary mask of retinal area (optional, eliminates halo artifacts)
%
% Output:
%   normImg - Illumination-normalized image (uint8)

    if nargin < 2 || isempty(method),  method = 'subtraction'; end
    if nargin < 3 || isempty(sigma),   sigma = 30; end
    if nargin < 4,                     fovMask = []; end

    if isempty(fovMask)
        if ndims(img) == 3
            gray = rgb2gray(img);
        else
            gray = img;
        end
        fovMask = (gray > 10);
    end

    isRGB = (ndims(img) == 3 && size(img, 3) == 3);

    if isRGB
        normImg = zeros(size(img), 'like', img);
        for c = 1:3
            normImg(:, :, c) = normalize_channel(img(:, :, c), method, sigma, fovMask);
        end
    else
        normImg = normalize_channel(img, method, sigma, fovMask);
    end
end

function outCh = normalize_channel(ch, method, sigma, fovMask)
    dCh = double(ch);

    % To prevent border halo artifacts, fill background with mean of retina
    retinaPixels = dCh(fovMask);
    if isempty(retinaPixels)
        outCh = ch;
        return;
    end
    meanRetina = mean(retinaPixels);

    filledCh = dCh;
    filledCh(~fovMask) = meanRetina;

    % Estimate illumination background via large Gaussian filter
    bg = imgaussfilt(filledCh, sigma);

    switch lower(method)
        case {'division', 'ratio'}
            % Ratio normalization: I / (bg + eps) * meanRetina
            epsVal = 1e-4;
            corrected = (dCh ./ (bg + epsVal)) * meanRetina;
        case {'subtraction', 'background_subtraction'}
            % Subtractive normalization: I - bg + meanRetina
            corrected = dCh - bg + meanRetina;
        otherwise
            corrected = dCh - bg + meanRetina;
    end

    % Re-apply zero background outside FOV
    corrected(~fovMask) = 0;

    % Clip to standard uint8 dynamic range [0, 255]
    corrected = max(0, min(255, corrected));
    outCh = uint8(corrected);
end
