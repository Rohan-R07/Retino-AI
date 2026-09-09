function [resizedImg, scaleInfo] = resize_fundus(img, targetSize)
% RESIZE_FUNDUS Rescales fundus image to standardized dimensions
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Inputs:
%   img        - Input RGB or grayscale image
%   targetSize - Target [height, width] vector (default: from training_config or [512, 512])
%
% Outputs:
%   resizedImg - Rescaled image
%   scaleInfo  - Struct with scale factors and original size

    if nargin < 2 || isempty(targetSize)
        try
            trainCfg = training_config();
            targetSize = trainCfg.image.target_size;
        catch
            targetSize = [512, 512];
        end
    end

    origSize = [size(img, 1), size(img, 2)];
    scaleInfo = struct();
    scaleInfo.original_size = origSize;
    scaleInfo.target_size = targetSize;
    scaleInfo.scale_factors = targetSize ./ origSize;

    if isequal(origSize, targetSize)
        resizedImg = img;
    else
        resizedImg = imresize(img, targetSize, 'bicubic');
    end
end
