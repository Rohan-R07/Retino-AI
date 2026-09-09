function greenCh = extract_green_channel(img)
% EXTRACT_GREEN_CHANNEL Extracts green color plane for vessel & lesion analysis
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Why Green Channel?
%   In retinal fundus imaging, the green channel provides the highest contrast
%   between vascular structures, hemorrhages, microaneurysms, and the retinal pigment background.
%   The red channel is typically saturated/washed out, and the blue channel suffers from poor illumination.
%
% Input:
%   img - RGB image [H x W x 3] or single-channel array
%
% Output:
%   greenCh - uint8 single-channel green matrix [H x W]

    if ndims(img) == 3 && size(img, 3) >= 2
        greenCh = img(:, :, 2);
    else
        greenCh = img(:, :, 1);
    end
end
