function overlayImg = visualize_lesions(origImg, lesionMasks, colors)
% VISUALIZE_LESIONS Overlays color-coded lesion boundaries onto retinal fundus image
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Visual Standards:
%   - Microaneurysms (MA) : Red boundary
%   - Hemorrhages (HE)    : Orange boundary
%   - Hard Exudates (EX)  : Yellow boundary
%   - Cotton Wool Spots   : Cyan boundary
%
% Inputs:
%   origImg     - uint8 RGB fundus image
%   lesionMasks - Struct containing binary masks (.microaneurysms, .hemorrhages, .hard_exudates)
%   colors      - Optional struct of RGB color definitions

    overlayImg = origImg;

    if nargin < 2 || isempty(lesionMasks)
        return;
    end

    % Microaneurysms (Red)
    if isfield(lesionMasks, 'microaneurysms') && any(lesionMasks.microaneurysms(:))
        overlayImg = draw_mask_contour(overlayImg, lesionMasks.microaneurysms, [255, 0, 0]);
    end

    % Hemorrhages (Orange)
    if isfield(lesionMasks, 'hemorrhages') && any(lesionMasks.hemorrhages(:))
        overlayImg = draw_mask_contour(overlayImg, lesionMasks.hemorrhages, [255, 140, 0]);
    end

    % Hard Exudates (Yellow)
    if isfield(lesionMasks, 'hard_exudates') && any(lesionMasks.hard_exudates(:))
        overlayImg = draw_mask_contour(overlayImg, lesionMasks.hard_exudates, [255, 255, 0]);
    end
end

function out = draw_mask_contour(img, mask, color)
    out = img;
    dil = imdilate(mask, strel('disk', 2));
    perimeter = dil & ~mask;
    for c = 1:3
        ch = out(:, :, c);
        ch(perimeter) = color(c);
        out(:, :, c) = ch;
    end
end
