function compositeImg = generate_evidence_overlay(origImg, lesionMasks, vesselMask, options)
% GENERATE_EVIDENCE_OVERLAY Combines fundus image with visual clinical evidence
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Integrates:
%   - Original retinal anatomical context
%   - High-contrast vessel segmentation tree
%   - Multi-colored pathology boundaries (MAs, hemorrhages, exudates)
%
% Output:
%   compositeImg - Diagnostic visualization for ophthalmologist review

    if nargin < 4
        options = struct();
    end

    compositeImg = origImg;

    % 1. Blend vessel network (if provided)
    if nargin >= 3 && ~isempty(vesselMask)
        compositeImg = visualize_vessels(compositeImg, vesselMask, 0.35, [0, 220, 220]);
    end

    % 2. Draw lesion boundaries
    if nargin >= 2 && ~isempty(lesionMasks)
        compositeImg = visualize_lesions(compositeImg, lesionMasks);
    end
end
