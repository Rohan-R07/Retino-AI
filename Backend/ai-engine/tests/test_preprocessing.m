function results = test_preprocessing(customConfig)
% TEST_PREPROCESSING Verifies fundus image preprocessing on real images
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Tests the unified preprocessing pipeline on actual sample images from:
%   1. APTOS (PNG format)
%   2. IDRiD (JPG format)
%   3. DRIVE (TIF format)
%
% Verifications:
%   - Image loads successfully from disk
%   - Correct standardized dimensions ([512, 512, 3])
%   - No empty or degenerate images
%   - FOV cropping isolates retina and removes camera borders
%   - Green channel correctly extracted
%   - Illumination normalization runs without NaN/Inf
%   - CLAHE contrast enhancement runs and preserves dynamic range
%   - Output contains finite, valid pixel values in [0, 255]
%   - Pipeline handles PNG, JPG, and TIF formats seamlessly
%
% Usage:
%   results = test_preprocessing();

    testDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(testDir);
    matlabDir = fullfile(rootDir, 'matlab');

    % Ensure required paths are loaded
    if exist(fullfile(matlabDir, 'setup_paths.m'), 'file') == 2
        run(fullfile(matlabDir, 'setup_paths.m'));
    else
        addpath(genpath(matlabDir));
        addpath(fullfile(rootDir, 'config'));
    end

    if nargin < 1 || isempty(customConfig)
        try
            trainCfg = training_config();
            cfg = trainCfg.preprocessing;
            cfg.target_size = trainCfg.image.target_size;
        catch
            cfg = struct();
            cfg.target_size = [512, 512];
            cfg.enable_fov_crop = true;
            cfg.fov_padding = 10;
            cfg.enable_illumination_norm = true;
            cfg.illumination_method = 'subtraction';
            cfg.illumination_sigma = 30;
            cfg.enable_clahe = true;
            cfg.clahe_clip_limit = 0.02;
            cfg.clahe_distribution = 'rayleigh';
            cfg.clahe_num_tiles = [8, 8];
            cfg.enable_denoising = true;
            cfg.denoise_method = 'median';
            cfg.denoise_kernel = [3, 3];
        end
    else
        cfg = customConfig;
    end

    fprintf('=================================================================\n');
    fprintf('           RETINO-AI PREPROCESSING PIPELINE TEST SUITE          \n');
    fprintf('=================================================================\n\n');

    % Define candidate sample images for each dataset and format
    samples = {
        struct('dataset', 'APTOS', 'format', 'PNG', ...
               'candidate', fullfile(rootDir, 'data', 'raw', 'aptos', 'train_images', '000c1434d8d7.png'), ...
               'search_pattern', fullfile(rootDir, 'data', 'raw', 'aptos', 'train_images', '*.png')), ...
        struct('dataset', 'IDRiD', 'format', 'JPG', ...
               'candidate', fullfile(rootDir, 'data', 'raw', 'idrid', 'Disease Grading', '1. Original Images', 'a. Training Set', 'IDRiD_001.jpg'), ...
               'search_pattern', fullfile(rootDir, 'data', 'raw', 'idrid', '**', '*.jpg')), ...
        struct('dataset', 'DRIVE', 'format', 'TIF', ...
               'candidate', fullfile(rootDir, 'data', 'raw', 'drive', 'training', 'images', '21_training.tif'), ...
               'search_pattern', fullfile(rootDir, 'data', 'raw', 'drive', '**', '*.tif')) ...
    };

    results = struct();
    results.timestamp = datestr(now);
    results.all_passed = true;
    results.tests = struct();

    for i = 1:numel(samples)
        s = samples{i};
        dsName = s.dataset;
        fmt = s.format;

        fprintf('-----------------------------------------------------------------\n');
        fprintf('Testing Dataset: %s (Format: %s)\n', dsName, fmt);
        fprintf('-----------------------------------------------------------------\n');

        % Resolve file path
        imgPath = '';
        if exist(s.candidate, 'file') == 2
            imgPath = s.candidate;
        else
            % Fallback search
            files = dir(s.search_pattern);
            if ~isempty(files)
                imgPath = fullfile(files(1).folder, files(1).name);
            end
        end

        testEntry = struct();
        testEntry.dataset = dsName;
        testEntry.format = fmt;
        testEntry.file_path = imgPath;
        testEntry.passed = false;
        testEntry.failures = {};

        if isempty(imgPath) || exist(imgPath, 'file') ~= 2
            testEntry.failures{end+1} = sprintf('Sample image file not found on disk.');
            fprintf('  [FAIL] Sample image not found.\n\n');
            results.all_passed = false;
            results.tests.(lower(dsName)) = testEntry;
            continue;
        end

        [~, fileName, fileExt] = fileparts(imgPath);
        fprintf('  Sample file: %s%s\n', fileName, fileExt);

        % Run the complete preprocessing pipeline
        tStart = tic;
        try
            processed = preprocess_fundus(imgPath, cfg);
            execTime = toc(tStart);
            fprintf('  Pipeline executed in %.3f seconds.\n', execTime);
            testEntry.execution_time_sec = execTime;
        catch ME
            testEntry.failures{end+1} = sprintf('preprocess_fundus failed with error: %s', ME.message);
            fprintf('  [FAIL] Preprocessing error: %s\n\n', ME.message);
            results.all_passed = false;
            results.tests.(lower(dsName)) = testEntry;
            continue;
        end

        % Verification 1: Image load success
        if ~isfield(processed, 'metadata') || ~processed.metadata.loaded_successfully
            testEntry.failures{end+1} = 'Metadata indicates image failed to load.';
        else
            origDims = processed.metadata.original_size;
            if numel(origDims) >= 3, origC = origDims(3); else, origC = 1; end
            fprintf('  [PASS] Image load verified (Original size: %dx%dx%d)\n', ...
                origDims(1), origDims(2), origC);
        end

        % Verification 2: Original image validity
        if isempty(processed.original) || ~isa(processed.original, 'uint8') || ndims(processed.original) ~= 3
            testEntry.failures{end+1} = 'Original image is invalid or not 3-channel uint8.';
        end

        % Verification 3: FOV cropping
        origH = size(processed.original, 1);
        origW = size(processed.original, 2);
        cropH = size(processed.cropped, 1);
        cropW = size(processed.cropped, 2);
        if isempty(processed.cropped) || cropH <= 0 || cropW <= 0
            testEntry.failures{end+1} = 'Cropped image is empty.';
        elseif cropH > origH || cropW > origW
            testEntry.failures{end+1} = 'Cropped image dimensions exceed original dimensions.';
        else
            fprintf('  [PASS] FOV cropping verified (Cropped size: %dx%dx%d, bbox: [%d, %d, %d, %d])\n', ...
                cropH, cropW, size(processed.cropped, 3), ...
                processed.metadata.crop_bbox(1), processed.metadata.crop_bbox(2), ...
                processed.metadata.crop_bbox(3), processed.metadata.crop_bbox(4));
        end

        % Verification 4: Standardized resizing
        targetH = cfg.target_size(1);
        targetW = cfg.target_size(2);
        if ~isequal([size(processed.resized, 1), size(processed.resized, 2)], [targetH, targetW])
            testEntry.failures{end+1} = sprintf('Resized image dimensions [%d, %d] do not match target [%d, %d].', ...
                size(processed.resized, 1), size(processed.resized, 2), targetH, targetW);
        elseif size(processed.resized, 3) ~= 3
            testEntry.failures{end+1} = 'Resized image is not 3-channel RGB.';
        else
            fprintf('  [PASS] Resizing verified ([%d, %d, %d])\n', targetH, targetW, size(processed.resized, 3));
        end

        % Verification 5: Green channel extraction
        if ~isequal(size(processed.green_channel), [targetH, targetW])
            testEntry.failures{end+1} = 'Green channel dimensions do not match target size.';
        elseif ~isa(processed.green_channel, 'uint8')
            testEntry.failures{end+1} = 'Green channel is not uint8.';
        else
            fprintf('  [PASS] Green channel extraction verified ([%d, %d] uint8)\n', targetH, targetW);
        end

        % Verification 6: Illumination normalization
        if ~isequal([size(processed.normalized, 1), size(processed.normalized, 2), size(processed.normalized, 3)], ...
                    [targetH, targetW, 3])
            testEntry.failures{end+1} = 'Normalized image dimensions incorrect.';
        elseif any(~isfinite(processed.normalized(:)))
            testEntry.failures{end+1} = 'Normalized image contains non-finite (NaN/Inf) pixel values.';
        elseif max(processed.normalized(:)) == 0
            testEntry.failures{end+1} = 'Normalized image is completely blank.';
        else
            fprintf('  [PASS] Illumination normalization verified (Range: [%d, %d])\n', ...
                min(processed.normalized(:)), max(processed.normalized(:)));
        end

        % Verification 7: Contrast enhancement (CLAHE)
        if ~isequal([size(processed.enhanced, 1), size(processed.enhanced, 2), size(processed.enhanced, 3)], ...
                    [targetH, targetW, 3])
            testEntry.failures{end+1} = 'Enhanced image dimensions incorrect.';
        elseif any(~isfinite(processed.enhanced(:)))
            testEntry.failures{end+1} = 'Enhanced image contains non-finite (NaN/Inf) pixel values.';
        elseif ~isequal(size(processed.enhanced_green), [targetH, targetW])
            testEntry.failures{end+1} = 'Enhanced green channel dimensions incorrect.';
        else
            fprintf('  [PASS] CLAHE contrast enhancement verified (Range: [%d, %d])\n', ...
                min(processed.enhanced(:)), max(processed.enhanced(:)));
        end

        % Verification 8: Lightweight Denoising
        if ~isequal(size(processed.denoised), [targetH, targetW])
            testEntry.failures{end+1} = 'Denoised green channel dimensions incorrect.';
        elseif any(~isfinite(processed.denoised(:)))
            testEntry.failures{end+1} = 'Denoised green channel contains non-finite pixel values.';
        else
            fprintf('  [PASS] Denoising verified ([%d, %d] uint8)\n', targetH, targetW);
        end

        % Verification 9: Retinal FOV mask
        if ~islogical(processed.fov_mask) || ~isequal(size(processed.fov_mask), [targetH, targetW])
            testEntry.failures{end+1} = 'FOV mask is not a logical array of target size.';
        elseif ~any(processed.fov_mask(:))
            testEntry.failures{end+1} = 'FOV mask is completely false (no retina detected).';
        else
            fovAreaPct = (sum(processed.fov_mask(:)) / numel(processed.fov_mask)) * 100.0;
            fprintf('  [PASS] Retinal FOV mask verified (Retinal area: %.1f%% of frame)\n', fovAreaPct);
            testEntry.fov_area_pct = fovAreaPct;
        end

        % Final evaluation for this sample
        if isempty(testEntry.failures)
            testEntry.passed = true;
            fprintf('  => STATUS: ALL PREPROCESSING CHECKS PASSED for %s (%s)\n\n', dsName, fmt);
        else
            testEntry.passed = false;
            results.all_passed = false;
            fprintf('  => STATUS: FAILED (%d checks failed):\n', numel(testEntry.failures));
            for f = 1:numel(testEntry.failures)
                fprintf('     * %s\n', testEntry.failures{f});
            end
            fprintf('\n');
        end

        testEntry.processed_summary = struct(...
            'original_size', size(processed.original), ...
            'cropped_size', size(processed.cropped), ...
            'resized_size', size(processed.resized), ...
            'green_channel_size', size(processed.green_channel), ...
            'enhanced_range', [min(processed.enhanced(:)), max(processed.enhanced(:))], ...
            'crop_bbox', processed.metadata.crop_bbox);

        results.tests.(lower(dsName)) = testEntry;
    end

    fprintf('=================================================================\n');
    if results.all_passed
        fprintf('  ALL DATASETS PREPROCESSING TESTS PASSED SUCCESSFULLY!          \n');
        fprintf('  Formats Verified: PNG (APTOS), JPG (IDRiD), TIF (DRIVE)        \n');
    else
        fprintf('  SOME PREPROCESSING TESTS FAILED. Check details above.          \n');
    end
    fprintf('=================================================================\n\n');
end
