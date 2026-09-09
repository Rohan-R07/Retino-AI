function [fovScore, isComplete, details] = check_fov(img, fovMask, minAreaRatio, minCircularity)
% CHECK_FOV Assesses field-of-view completeness, retinal area, and camera alignment
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Audits:
%   - Whether the circular retinal aperture occupies an adequate fraction of the frame
%   - Detects images with insufficient retinal area or severely cropped / invalid FOV
%   - Reuses FOV mask from preprocessing to eliminate duplicate computations
%
% Inputs:
%   img            - RGB or grayscale fundus image
%   fovMask        - Logical retinal mask (reused from preprocessing)
%   minAreaRatio   - Minimum retinal area fraction of image frame (default: from config or 0.25)
%   minCircularity - Minimum circularity metric of retinal mask (default: from config or 0.35)
%
% Outputs:
%   fovScore   - Metric [0.0 to 1.0] based on area ratio and circularity
%   isComplete - Logical flag (true if FOV meets retinal completeness criteria)
%   details    - Struct with area measurements, circularity, and audit info

    try
        trainCfg = training_config();
        defMinAreaRatio = trainCfg.quality.min_fov_ratio;
        defMinCircularity = trainCfg.quality.min_circularity;
    catch
        defMinAreaRatio = 0.25;
        defMinCircularity = 0.35;
    end

    if nargin < 3 || isempty(minAreaRatio),   minAreaRatio = defMinAreaRatio;     end
    if nargin < 4 || isempty(minCircularity), minCircularity = defMinCircularity; end

    totalPixels = size(img, 1) * size(img, 2);

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

    retinaArea = sum(fovMask(:));
    if totalPixels > 0
        areaRatio = retinaArea / totalPixels;
    else
        areaRatio = 0.0;
    end

    % Measure circularity of the largest connected retinal component
    cc = bwconncomp(fovMask);
    circularity = 0.0;
    if cc.NumObjects > 0
        props = regionprops(cc, 'Area', 'Perimeter');
        [~, maxIdx] = max([props.Area]);
        perim = props(maxIdx).Perimeter;
        area = props(maxIdx).Area;
        if perim > 0
            circularity = (4 * pi * area) / (perim ^ 2);
        end
    end

    isAreaOk = (areaRatio >= minAreaRatio);
    isShapeOk = (circularity >= minCircularity);
    isComplete = logical(isAreaOk && isShapeOk);

    % Combined normalized score [0 to 1]
    normArea = min(1.0, areaRatio / 0.50);
    normCirc = min(1.0, circularity);
    fovScore = (0.60 * normArea) + (0.40 * normCirc);

    verdict = 'complete';
    if ~isAreaOk
        verdict = 'insufficient_area';
    elseif ~isShapeOk
        verdict = 'distorted_shape';
    end

    details = struct();
    details.retina_area_ratio = areaRatio;
    details.retina_area_pixels = retinaArea;
    details.total_pixels = totalPixels;
    details.circularity = circularity;
    details.min_area_ratio_threshold = minAreaRatio;
    details.min_circularity_threshold = minCircularity;
    details.is_complete = isComplete;
    details.is_area_ok = isAreaOk;
    details.is_shape_ok = isShapeOk;
    details.verdict = verdict;
end
