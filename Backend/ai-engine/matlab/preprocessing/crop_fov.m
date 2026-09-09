function [croppedImg, fovMask, bbox] = crop_fov(img, threshold, padding)
% CROP_FOV Detects the circular field-of-view (FOV) aperture and tightly crops the retina
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Objectives:
%   - Isolates the circular retinal aperture from dark camera borders
%   - Adds a protective padding margin to prevent accidental cropping of peripheral retina
%   - Returns cropped image, tight binary FOV mask, and bounding box
%
% Inputs:
%   img       - uint8 RGB or grayscale fundus image
%   threshold - Luminance cutoff (default: adaptive 10-15)
%   padding   - Safety pixel margin added around detected FOV (default: 10)
%
% Outputs:
%   croppedImg - Tightly cropped fundus image
%   fovMask    - Binary mask of the retinal area within the FOV
%   bbox       - Bounding box [x, y, width, height]

    if ndims(img) == 3
        gray = rgb2gray(img);
    else
        gray = img;
    end

    if nargin < 2 || isempty(threshold)
        % Adaptive threshold based on low-luminance quantile
        estimatedCutoff = round(graythresh(gray) * 255 * 0.15);
        threshold = max(5, min(20, estimatedCutoff));
    end

    if nargin < 3 || isempty(padding)
        padding = 10;
    end

    % Binary threshold to separate retina from black background
    rawMask = (gray > threshold);

    % Morphological cleanup: bridge perimeter gaps and fill interior
    se = strel('disk', 5);
    cleanMask = imclose(rawMask, se);
    cleanMask = imfill(cleanMask, 'holes');

    % Retain largest connected component (the circular retina)
    cc = bwconncomp(cleanMask);
    if cc.NumObjects > 0
        props = regionprops(cc, 'Area', 'BoundingBox');
        [~, largestIdx] = max([props.Area]);
        rawBbox = round(props(largestIdx).BoundingBox);

        % Apply safety margin padding without exceeding image boundaries
        H = size(img, 1);
        W = size(img, 2);

        x1 = max(1, rawBbox(1) - padding);
        y1 = max(1, rawBbox(2) - padding);
        x2 = min(W, rawBbox(1) + rawBbox(3) + padding);
        y2 = min(H, rawBbox(2) + rawBbox(4) + padding);

        bbox = [x1, y1, (x2 - x1), (y2 - y1)];

        croppedImg = img(y1:y2, x1:x2, :);
        fovMask = cleanMask(y1:y2, x1:x2);
    else
        % Fallback if mask detection fails
        bbox = [1, 1, size(img, 2), size(img, 1)];
        croppedImg = img;
        fovMask = true(size(gray));
    end
end
