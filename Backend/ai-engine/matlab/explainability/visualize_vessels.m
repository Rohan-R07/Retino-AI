function overlayImg = visualize_vessels(origImg, vesselMask, alpha, vesselColor)
% VISUALIZE_VESSELS Overlays segmented retinal vasculature onto fundus photograph
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Inputs:
%   origImg     - uint8 RGB fundus image
%   vesselMask  - Binary mask of segmented blood vessel tree
%   alpha       - Blending transparency [0.0 to 1.0] (default: 0.4)
%   vesselColor - RGB triplet (default: [0, 255, 255] cyan)
%
% Output:
%   overlayImg - Blended RGB visualization

    if nargin < 3 || isempty(alpha), alpha = 0.4; end
    if nargin < 4 || isempty(vesselColor), vesselColor = [0, 255, 255]; end

    overlayImg = origImg;
    if isempty(vesselMask) || ~any(vesselMask(:))
        return;
    end

    % Resize vessel mask if dimensions mismatch
    if ~isequal(size(vesselMask), [size(origImg, 1), size(origImg, 2)])
        vesselMask = imresize(vesselMask, [size(origImg, 1), size(origImg, 2)], 'nearest');
    end

    for c = 1:3
        origCh = double(origImg(:, :, c));
        blend = (1 - alpha) * origCh + alpha * vesselColor(c);
        origCh(vesselMask) = blend(vesselMask);
        overlayImg(:, :, c) = uint8(origCh);
    end
end
