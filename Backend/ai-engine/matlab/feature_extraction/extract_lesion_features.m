function lesionFeats = extract_lesion_features(lesionMasks, fovMask)
% EXTRACT_LESION_FEATURES Quantifies pathological lesion area and count from IDRiD masks
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Features Extracted (from ground-truth segmentation masks):
%   1. microaneurysm_area   - Area ratio of microaneurysms to retinal FOV
%   2. microaneurysm_count  - Number of distinct microaneurysm foci
%   3. hemorrhage_area      - Area ratio of hemorrhages to retinal FOV
%   4. hemorrhage_count     - Number of distinct hemorrhage patches
%   5. hard_exudate_area    - Area ratio of hard exudates to retinal FOV
%   6. hard_exudate_count   - Number of distinct hard exudate clusters
%   7. soft_exudate_area    - Area ratio of soft exudates (cotton-wool spots)
%   8. soft_exudate_count   - Number of distinct soft exudate patches
%
% Inputs:
%   lesionMasks - Struct containing optional fields:
%                 .ma_mask (or .microaneurysms)
%                 .he_mask (or .haemorrhages / .hemorrhages)
%                 .ex_mask (or .hard_exudates)
%                 .se_mask (or .soft_exudates)
%   fovMask     - Logical mask of the retinal FOV
%
% Output:
%   lesionFeats - Struct containing the 8 lesion area and count descriptors

    lesionFeats = struct();

    if nargin < 2 || isempty(fovMask)
        fovMask = [];
    else
        fovMask = logical(fovMask);
    end

    totalRetinaArea = max(1, sum(fovMask(:)));

    % Initialize all features to 0.0 (ensures consistent numeric vector across all datasets)
    lesionFeats.microaneurysm_area  = 0.0;
    lesionFeats.microaneurysm_count = 0.0;
    lesionFeats.hemorrhage_area     = 0.0;
    lesionFeats.hemorrhage_count    = 0.0;
    lesionFeats.hard_exudate_area   = 0.0;
    lesionFeats.hard_exudate_count  = 0.0;
    lesionFeats.soft_exudate_area   = 0.0;
    lesionFeats.soft_exudate_count  = 0.0;

    if nargin < 1 || isempty(lesionMasks) || ~isstruct(lesionMasks)
        return;
    end

    % 1. Microaneurysms
    maMask = get_mask_field(lesionMasks, {'ma_mask', 'microaneurysms', 'ma'});
    [lesionFeats.microaneurysm_area, lesionFeats.microaneurysm_count] = ...
        compute_lesion_stats(maMask, fovMask, totalRetinaArea);

    % 2. Hemorrhages
    heMask = get_mask_field(lesionMasks, {'he_mask', 'haemorrhages', 'hemorrhages', 'he'});
    [lesionFeats.hemorrhage_area, lesionFeats.hemorrhage_count] = ...
        compute_lesion_stats(heMask, fovMask, totalRetinaArea);

    % 3. Hard Exudates
    exMask = get_mask_field(lesionMasks, {'ex_mask', 'hard_exudates', 'exudates', 'ex'});
    [lesionFeats.hard_exudate_area, lesionFeats.hard_exudate_count] = ...
        compute_lesion_stats(exMask, fovMask, totalRetinaArea);

    % 4. Soft Exudates (Cotton-Wool Spots)
    seMask = get_mask_field(lesionMasks, {'se_mask', 'soft_exudates', 'cotton_wool_spots', 'se'});
    [lesionFeats.soft_exudate_area, lesionFeats.soft_exudate_count] = ...
        compute_lesion_stats(seMask, fovMask, totalRetinaArea);
end

function mask = get_mask_field(s, aliases)
    mask = [];
    for i = 1:numel(aliases)
        if isfield(s, aliases{i}) && ~isempty(s.(aliases{i}))
            mask = s.(aliases{i});
            return;
        end
    end
end

function [areaRatio, objCount] = compute_lesion_stats(mask, fovMask, totalArea)
    if isempty(mask) || ~any(mask(:))
        areaRatio = 0.0;
        objCount = 0.0;
        return;
    end

    binMask = logical(mask > 0);

    % Align dimensions with FOV mask if needed
    if ~isempty(fovMask) && ~isequal(size(binMask), size(fovMask))
        binMask = imresize(binMask, size(fovMask), 'nearest');
    end

    if ~isempty(fovMask)
        validMask = binMask & fovMask;
    else
        validMask = binMask;
    end

    areaPixels = sum(validMask(:));
    areaRatio = areaPixels / totalArea;

    cc = bwconncomp(validMask);
    objCount = double(cc.NumObjects);
end
