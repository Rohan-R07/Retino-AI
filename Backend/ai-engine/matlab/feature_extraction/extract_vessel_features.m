function vesselFeats = extract_vessel_features(vesselMask, fovMask)
% EXTRACT_VESSEL_FEATURES Extracts vascular density and morphology features
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Features Extracted:
%   1. vessel_density      - Ratio of vessel pixels to total retinal FOV pixels
%   2. vessel_edge_density - Ratio of vessel perimeter/edge pixels to total retinal FOV pixels
%
% Inputs:
%   vesselMask - Logical or binary vessel segmentation mask (from DRIVE ground truth)
%   fovMask    - Logical mask of the retinal FOV
%
% Output:
%   vesselFeats - Struct containing the 2 vessel scalar descriptors

    vesselFeats = struct();

    if nargin < 2 || isempty(fovMask)
        if ~isempty(vesselMask)
            fovMask = true(size(vesselMask));
        else
            fovMask = [];
        end
    else
        fovMask = logical(fovMask);
    end

    totalRetinaArea = max(1, sum(fovMask(:)));

    if nargin >= 1 && ~isempty(vesselMask) && any(vesselMask(:))
        % Ensure binary logical mask
        binVessel = logical(vesselMask > 0);

        % Match dimensions if mask size differs from FOV mask
        if ~isempty(fovMask) && ~isequal(size(binVessel), size(fovMask))
            binVessel = imresize(binVessel, size(fovMask), 'nearest');
        end

        % Mask inside FOV
        if ~isempty(fovMask)
            vesselInRetina = binVessel & fovMask;
        else
            vesselInRetina = binVessel;
        end

        vesselArea = sum(vesselInRetina(:));
        vesselFeats.vessel_density = vesselArea / totalRetinaArea;

        % Vessel edge perimeter
        vesselEdges = bwperim(vesselInRetina);
        edgeCount = sum(vesselEdges(:));
        vesselFeats.vessel_edge_density = edgeCount / totalRetinaArea;
    else
        % No vessel mask provided (e.g. APTOS / non-segmented datasets)
        vesselFeats.vessel_density = 0.0;
        vesselFeats.vessel_edge_density = 0.0;
    end
end
