function denoisedImg = denoise_fundus(img, method, kernelSize)
% DENOISE_FUNDUS Lightweight edge-preserving denoising for retinal imagery
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Strategy:
%   Applies lightweight spatial filtering (default: 3x3 median filter) to suppress
%   sensor noise and camera grain while preserving fine pathological structures
%   such as microaneurysms, capillary vessels, and hemorrhage boundaries.
%
% Inputs:
%   img        - uint8 RGB or grayscale/green image
%   method     - 'median' (default), 'gaussian', or 'none'
%   kernelSize - Filter window [H, W] (default: [3, 3])
%
% Output:
%   denoisedImg - Filtered image with noise suppressed and lesions preserved

    if nargin < 2 || isempty(method),     method = 'median'; end
    if nargin < 3 || isempty(kernelSize), kernelSize = [3, 3]; end

    switch lower(method)
        case 'none'
            denoisedImg = img;
            return;

        case 'median'
            if ndims(img) == 3 && size(img, 3) == 3
                denoisedImg = zeros(size(img), 'like', img);
                for c = 1:3
                    denoisedImg(:, :, c) = medfilt2(img(:, :, c), kernelSize);
                end
            else
                denoisedImg = medfilt2(img, kernelSize);
            end

        case 'gaussian'
            % Mild Gaussian blur (sigma = 0.8) to prevent lesion erasure
            sigma = 0.8;
            if ndims(img) == 3 && size(img, 3) == 3
                denoisedImg = imgaussfilt(img, sigma);
            else
                denoisedImg = imgaussfilt(img, sigma);
            end

        otherwise
            warning('RetinoAI:UnknownDenoiseMethod', ...
                'Unknown denoising method ''%s''. Using default 3x3 median filter.', method);
            denoisedImg = denoise_fundus(img, 'median', kernelSize);
    end
end
