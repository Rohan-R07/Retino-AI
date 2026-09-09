function [img, meta] = load_fundus(inputSource)
% LOAD_FUNDUS Loads and standardizes a retinal fundus photograph from file or array
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Input:
%   inputSource - File path string (JPEG, PNG, TIFF, DICOM) or existing RGB/grayscale array
%
% Output:
%   img  - Standardized uint8 RGB image array [H x W x 3]
%   meta - Struct containing format, original dimensions, and color space information

    meta = struct();
    meta.loaded_successfully = false;
    meta.original_size = [];
    meta.source = '';

    if ischar(inputSource) || isstring(inputSource)
        filePath = char(inputSource);
        meta.source = filePath;
        if exist(filePath, 'file') ~= 2
            error('RetinoAI:FileNotFound', 'Fundus image file does not exist: %s', filePath);
        end

        [~, ~, ext] = fileparts(filePath);
        if strcmpi(ext, '.dcm')
            raw = dicomread(filePath);
        else
            raw = imread(filePath);
        end
    elseif isnumeric(inputSource) || islogical(inputSource)
        raw = inputSource;
        meta.source = 'in_memory_array';
    else
        error('RetinoAI:InvalidInput', 'Input must be a file path string or an image matrix.');
    end

    meta.original_size = size(raw);

    % Standardize data type to uint8
    if isa(raw, 'double') || isa(raw, 'single')
        if max(raw(:)) <= 1.0
            raw = uint8(raw * 255);
        else
            raw = uint8(raw);
        end
    elseif ~isa(raw, 'uint8')
        raw = im2uint8(raw);
    end

    % Ensure 3-channel RGB format
    if ndims(raw) == 2
        img = cat(3, raw, raw, raw);
        meta.color_space = 'grayscale_converted_to_rgb';
    elseif size(raw, 3) == 4
        % RGBA: drop alpha channel
        img = raw(:, :, 1:3);
        meta.color_space = 'rgba_stripped_to_rgb';
    else
        img = raw(:, :, 1:3);
        meta.color_space = 'rgb';
    end

    meta.loaded_successfully = true;
end
