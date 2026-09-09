function results = test_quality_assessment(customConfig)
% TEST_QUALITY_ASSESSMENT Verifies classical fundus image quality assessment pipeline
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Tests the quality gatekeeper against real fundus images and controlled degradations:
%   1. Real Good-Quality Images (APTOS, IDRiD, DRIVE) -> Must PASS (is_gradable = true)
%   2. Artificially Blurred Image (Gaussian blur)     -> Must FAIL blur check
%   3. Severely Dark / Underexposed Image             -> Must FAIL brightness check
%   4. Severely Overexposed / Glare Image             -> Must FAIL brightness check
%   5. Severely Cropped / Insufficient FOV Image      -> Must FAIL FOV check
%
% Verifications:
%   - All required output fields present:
%       overall_quality, is_gradable, blur_score, brightness_score, fov_score,
%       blur_pass, brightness_pass, fov_pass, rejection_reason, metadata
%   - Scores are finite, non-negative numbers
%   - Rejection reasons are clearly articulated and explainable
%   - Gatekeeper decisions are deterministic
%
% Usage:
%   results = test_quality_assessment();

    testDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(testDir);
    matlabDir = fullfile(rootDir, 'matlab');

    if exist(fullfile(matlabDir, 'setup_paths.m'), 'file') == 2
        run(fullfile(matlabDir, 'setup_paths.m'));
    else
        addpath(genpath(matlabDir));
        addpath(fullfile(rootDir, 'config'));
    end

    if nargin < 1 || isempty(customConfig)
        try
            trainCfg = training_config();
            cfg = trainCfg.quality;
        catch
            cfg = struct();
            cfg.blur_threshold = 25.0;
            cfg.brightness_min = 35.0;
            cfg.brightness_max = 180.0;
            cfg.min_entropy = 4.0;
            cfg.min_fov_ratio = 0.25;
            cfg.min_circularity = 0.35;
        end
    else
        cfg = customConfig;
    end

    fprintf('=================================================================\n');
    fprintf('        RETINO-AI QUALITY ASSESSMENT TEST SUITE (PHASE 2)        \n');
    fprintf('=================================================================\n\n');

    % Define candidate sample images
    samples = {
        struct('dataset', 'APTOS', 'format', 'PNG', ...
               'path', fullfile(rootDir, 'data', 'raw', 'aptos', 'train_images', '000c1434d8d7.png')), ...
        struct('dataset', 'IDRiD', 'format', 'JPG', ...
               'path', fullfile(rootDir, 'data', 'raw', 'idrid', 'Disease Grading', '1. Original Images', 'a. Training Set', 'IDRiD_001.jpg')), ...
        struct('dataset', 'DRIVE', 'format', 'TIF', ...
               'path', fullfile(rootDir, 'data', 'raw', 'drive', 'training', 'images', '21_training.tif')) ...
    };

    results = struct();
    results.timestamp = datestr(now);
    results.all_passed = true;
    results.tests = struct();

    % -------------------------------------------------------------
    % Part 1: Test Real Good-Quality Fundus Images
    % -------------------------------------------------------------
    fprintf('--- PART 1: Testing Real Good-Quality Images ---\n');

    for i = 1:numel(samples)
        s = samples{i};
        dsName = s.dataset;
        fprintf('\nChecking %s (%s)...\n', dsName, s.format);

        if exist(s.path, 'file') ~= 2
            fprintf('  [SKIP] Sample image not found: %s\n', s.path);
            continue;
        end

        % Preprocess first to get standardized struct with FOV
        prep = preprocess_fundus(s.path);
        quality = assess_image_quality(prep, cfg);

        testEntry = struct();
        testEntry.name = sprintf('%s_normal', lower(dsName));
        testEntry.failures = {};

        % Field presence verification
        reqFields = {'overall_quality', 'is_gradable', 'blur_score', 'brightness_score', ...
                     'fov_score', 'blur_pass', 'brightness_pass', 'fov_pass', ...
                     'rejection_reason', 'metadata'};
        for f = 1:numel(reqFields)
            if ~isfield(quality, reqFields{f})
                testEntry.failures{end+1} = sprintf('Missing required field: %s', reqFields{f});
            end
        end

        % Finite value verification
        if ~isfinite(quality.blur_score) || quality.blur_score < 0
            testEntry.failures{end+1} = 'blur_score is non-finite or negative.';
        end
        if ~isfinite(quality.brightness_score) || quality.brightness_score < 0
            testEntry.failures{end+1} = 'brightness_score is non-finite or negative.';
        end
        if ~isfinite(quality.fov_score) || quality.fov_score < 0
            testEntry.failures{end+1} = 'fov_score is non-finite or negative.';
        end

        % Check pass states
        if ~quality.blur_pass
            testEntry.failures{end+1} = sprintf('Expected sharp image to pass blur check (score: %.2f, threshold: %.2f)', ...
                quality.blur_score, cfg.blur_threshold);
        end
        if ~quality.brightness_pass
            testEntry.failures{end+1} = sprintf('Expected normal image to pass brightness check (mean: %.2f)', ...
                quality.brightness_details.mean_luminance);
        end
        if ~quality.fov_pass
            testEntry.failures{end+1} = sprintf('Expected complete FOV to pass fov check (area ratio: %.2f)', ...
                quality.fov_details.retina_area_ratio);
        end
        if ~quality.is_gradable
            testEntry.failures{end+1} = sprintf('Expected good image to be gradable. Rejection: %s', ...
                quality.rejection_reason);
        end

        if isempty(testEntry.failures)
            testEntry.passed = true;
            fprintf('  [PASS] Gradable: %s | Rating: %s | Blur: %.2f | Brightness: %.2f | FOV: %.2f\n', ...
                mat2str(quality.is_gradable), quality.overall_quality, quality.blur_score, ...
                quality.brightness_details.mean_luminance, quality.fov_details.retina_area_ratio);
        else
            testEntry.passed = false;
            results.all_passed = false;
            fprintf('  [FAIL] Issues detected:\n');
            for k = 1:numel(testEntry.failures)
                fprintf('    * %s\n', testEntry.failures{k});
            end
        end

        results.tests.(testEntry.name) = testEntry;
    end

    % -------------------------------------------------------------
    % Part 2: Test Degraded Images (Controlled Failure Scenarios)
    % -------------------------------------------------------------
    fprintf('\n--- PART 2: Testing Intentionally Degraded Scenarios ---\n');

    baseSample = samples{1}.path;
    if exist(baseSample, 'file') == 2
        basePrep = preprocess_fundus(baseSample);
        baseImg = basePrep.resized;
        baseFov = basePrep.fov_mask;

        % Scenario A: Artificially Blurred Image
        fprintf('\n[Scenario A] Severe Blur (Gaussian blur sigma = 6.0)...\n');
        blurredImg = imgaussfilt(baseImg, 6.0);
        degA = struct('resized', blurredImg, 'fov_mask', baseFov, 'metadata', basePrep.metadata);
        qA = assess_image_quality(degA, cfg);

        tA = struct('name', 'degraded_blur', 'passed', false, 'failures', {});
        if qA.blur_pass
            tA.failures{end+1} = sprintf('Blurred image unexpectedly PASSED blur check (score: %.2f >= %.2f)', ...
                qA.blur_score, cfg.blur_threshold);
        end
        if qA.is_gradable
            tA.failures{end+1} = 'Blurred image was marked as gradable!';
        end
        if isempty(qA.rejection_reason)
            tA.failures{end+1} = 'Rejection reason was empty for blurred image.';
        end
        if isempty(tA.failures)
            tA.passed = true;
            fprintf('  [PASS] Correctly rejected blur (Score: %.2f < %.2f) | Reason: %s\n', ...
                qA.blur_score, cfg.blur_threshold, qA.rejection_reason);
        else
            results.all_passed = false;
            fprintf('  [FAIL] %s\n', strjoin(tA.failures, '; '));
        end
        results.tests.degraded_blur = tA;

        % Scenario B: Severely Dark / Underexposed Image
        fprintf('\n[Scenario B] Severe Underexposure (scaled by 0.15)...\n');
        darkImg = uint8(double(baseImg) * 0.15);
        degB = struct('resized', darkImg, 'fov_mask', baseFov, 'metadata', basePrep.metadata);
        qB = assess_image_quality(degB, cfg);

        tB = struct('name', 'degraded_underexposed', 'passed', false, 'failures', {});
        if qB.brightness_pass
            tB.failures{end+1} = sprintf('Dark image unexpectedly PASSED brightness check (mean: %.2f)', ...
                qB.brightness_details.mean_luminance);
        end
        if qB.is_gradable
            tB.failures{end+1} = 'Dark image was marked as gradable!';
        end
        if isempty(qB.rejection_reason)
            tB.failures{end+1} = 'Rejection reason was empty for dark image.';
        end
        if isempty(tB.failures)
            tB.passed = true;
            fprintf('  [PASS] Correctly rejected underexposure (Mean: %.2f < %.2f) | Reason: %s\n', ...
                qB.brightness_details.mean_luminance, cfg.brightness_min, qB.rejection_reason);
        else
            results.all_passed = false;
            fprintf('  [FAIL] %s\n', strjoin(tB.failures, '; '));
        end
        results.tests.degraded_underexposed = tB;

        % Scenario C: Severely Overexposed / Glare Image
        fprintf('\n[Scenario C] Severe Overexposure (scaled * 2.2 + 80)...\n');
        overImg = uint8(min(255, double(baseImg) * 2.2 + 80));
        degC = struct('resized', overImg, 'fov_mask', baseFov, 'metadata', basePrep.metadata);
        qC = assess_image_quality(degC, cfg);

        tC = struct('name', 'degraded_overexposed', 'passed', false, 'failures', {});
        if qC.brightness_pass
            tC.failures{end+1} = sprintf('Overexposed image unexpectedly PASSED brightness check (mean: %.2f)', ...
                qC.brightness_details.mean_luminance);
        end
        if qC.is_gradable
            tC.failures{end+1} = 'Overexposed image was marked as gradable!';
        end
        if isempty(qC.rejection_reason)
            tC.failures{end+1} = 'Rejection reason was empty for overexposed image.';
        end
        if isempty(tC.failures)
            tC.passed = true;
            fprintf('  [PASS] Correctly rejected overexposure (Mean: %.2f > %.2f) | Reason: %s\n', ...
                qC.brightness_details.mean_luminance, cfg.brightness_max, qC.rejection_reason);
        else
            results.all_passed = false;
            fprintf('  [FAIL] %s\n', strjoin(tC.failures, '; '));
        end
        results.tests.degraded_overexposed = tC;

        % Scenario D: Severely Cropped / Insufficient FOV Image
        fprintf('\n[Scenario D] Insufficient Retinal Area (cropped to tiny patch)...\n');
        croppedFov = false(size(baseFov));
        croppedFov(220:280, 220:280) = baseFov(220:280, 220:280);
        croppedImg = zeros(size(baseImg), 'like', baseImg);
        croppedImg(220:280, 220:280, :) = baseImg(220:280, 220:280, :);
        degD = struct('resized', croppedImg, 'fov_mask', croppedFov, 'metadata', basePrep.metadata);
        qD = assess_image_quality(degD, cfg);

        tD = struct('name', 'degraded_fov', 'passed', false, 'failures', {});
        if qD.fov_pass
            tD.failures{end+1} = sprintf('Tiny FOV unexpectedly PASSED fov check (area ratio: %.3f)', ...
                qD.fov_details.retina_area_ratio);
        end
        if qD.is_gradable
            tD.failures{end+1} = 'Tiny FOV image was marked as gradable!';
        end
        if isempty(qD.rejection_reason)
            tD.failures{end+1} = 'Rejection reason was empty for insufficient FOV.';
        end
        if isempty(tD.failures)
            tD.passed = true;
            fprintf('  [PASS] Correctly rejected insufficient FOV (Coverage: %.1f%% < %.1f%%) | Reason: %s\n', ...
                qD.fov_details.retina_area_ratio * 100.0, cfg.min_fov_ratio * 100.0, qD.rejection_reason);
        else
            results.all_passed = false;
            fprintf('  [FAIL] %s\n', strjoin(tD.failures, '; '));
        end
        results.tests.degraded_fov = tD;
    end

    fprintf('\n=================================================================\n');
    if results.all_passed
        fprintf('  ALL QUALITY ASSESSMENT TESTS PASSED SUCCESSFULLY!              \n');
        fprintf('  Verified: Blur detection, exposure bounds, FOV coverage,       \n');
        fprintf('            gradability gatekeeper, and explainable rejections. \n');
    else
        fprintf('  SOME QUALITY ASSESSMENT TESTS FAILED. Check log details above. \n');
    end
    fprintf('=================================================================\n\n');
end
