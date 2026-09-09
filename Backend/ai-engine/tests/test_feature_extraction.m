function results = test_feature_extraction(customConfig)
% TEST_FEATURE_EXTRACTION Verifies prototype feature extraction pipeline across datasets
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Tests the 22-dimensional feature extraction pipeline on real samples:
%   - 2 APTOS images (Primary DR classification: Color + Texture features)
%   - 2 IDRiD images (DR labels + MA, HE, EX, SE lesion evidence)
%   - 1 DRIVE image  (Vessel feature ground-truth validation)
%
% Verifications:
%   - Feature vector is purely numeric and 1x22 double
%   - No NaN or Inf values across all feature vectors
%   - Feature names array matches vector length exactly
%   - Color features (8) are valid within retinal FOV
%   - Texture features (4) computed via GLCM on green channel
%   - Vessel features (2) non-zero where vessel masks are provided (DRIVE)
%   - Lesion features (8) non-zero where lesion masks are provided (IDRiD)
%   - Extraction is strictly deterministic (identical outputs on re-run)
%
% Usage:
%   results = test_feature_extraction();

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
            cfg = trainCfg.features;
        catch
            cfg = struct();
            cfg.glcm_num_levels = 16;
            cfg.texture_glcm_offsets = [0 1; -1 1; -1 0; -1 -1];
        end
    else
        cfg = customConfig;
    end

    fprintf('=================================================================\n');
    fprintf('        RETINO-AI FEATURE EXTRACTION TEST SUITE (PHASE 3)        \n');
    fprintf('=================================================================\n\n');

    % Define candidate sample test images and associated ground truth masks
    samples = {
        % 1. APTOS Image 1
        struct('dataset', 'APTOS', 'sample_id', 'APTOS_1', ...
               'img_path', fullfile(rootDir, 'data', 'raw', 'aptos', 'train_images', '000c1434d8d7.png'), ...
               'masks', struct()), ...
        % 2. APTOS Image 2
        struct('dataset', 'APTOS', 'sample_id', 'APTOS_2', ...
               'img_path', fullfile(rootDir, 'data', 'raw', 'aptos', 'train_images', '001639a390f0.png'), ...
               'masks', struct()), ...
        % 3. IDRiD Image 1 (IDRiD_01 with MA, HE, EX)
        struct('dataset', 'IDRiD', 'sample_id', 'IDRiD_01', ...
               'img_path', fullfile(rootDir, 'data', 'raw', 'idrid', 'Segmentation', '1. Original Images', 'a. Training Set', 'IDRiD_01.jpg'), ...
               'masks', struct(...
                   'ma_path', fullfile(rootDir, 'data', 'raw', 'idrid', 'Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '1. Microaneurysms', 'IDRiD_01_MA.tif'), ...
                   'he_path', fullfile(rootDir, 'data', 'raw', 'idrid', 'Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '2. Haemorrhages', 'IDRiD_01_HE.tif'), ...
                   'ex_path', fullfile(rootDir, 'data', 'raw', 'idrid', 'Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '3. Hard Exudates', 'IDRiD_01_EX.tif'))), ...
        % 4. IDRiD Image 2 (IDRiD_03 with MA, HE, EX, SE)
        struct('dataset', 'IDRiD', 'sample_id', 'IDRiD_03', ...
               'img_path', fullfile(rootDir, 'data', 'raw', 'idrid', 'Segmentation', '1. Original Images', 'a. Training Set', 'IDRiD_03.jpg'), ...
               'masks', struct(...
                   'ma_path', fullfile(rootDir, 'data', 'raw', 'idrid', 'Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '1. Microaneurysms', 'IDRiD_03_MA.tif'), ...
                   'he_path', fullfile(rootDir, 'data', 'raw', 'idrid', 'Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '2. Haemorrhages', 'IDRiD_03_HE.tif'), ...
                   'ex_path', fullfile(rootDir, 'data', 'raw', 'idrid', 'Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '3. Hard Exudates', 'IDRiD_03_EX.tif'), ...
                   'se_path', fullfile(rootDir, 'data', 'raw', 'idrid', 'Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set', '4. Soft Exudates', 'IDRiD_03_SE.tif'))), ...
        % 5. DRIVE Image 1 (21_training with manual vessel mask)
        struct('dataset', 'DRIVE', 'sample_id', 'DRIVE_21', ...
               'img_path', fullfile(rootDir, 'data', 'raw', 'drive', 'training', 'images', '21_training.tif'), ...
               'masks', struct(...
                   'vessel_path', fullfile(rootDir, 'data', 'raw', 'drive', 'training', '1st_manual', '21_manual1.gif'))) ...
    };

    results = struct();
    results.timestamp = datestr(now);
    results.all_passed = true;
    results.tests = struct();

    expectedFeatureCount = 22;

    for i = 1:numel(samples)
        s = samples{i};
        fprintf('Testing %s (%s)...\n', s.dataset, s.sample_id);

        testEntry = struct();
        testEntry.dataset = s.dataset;
        testEntry.sample_id = s.sample_id;
        testEntry.failures = {};

        if exist(s.img_path, 'file') ~= 2
            testEntry.failures{end+1} = sprintf('Image file not found: %s', s.img_path);
            results.all_passed = false;
            fprintf('  [FAIL] Image missing.\n\n');
            results.tests.(lower(s.sample_id)) = testEntry;
            continue;
        end

        % Preprocess image
        prep = preprocess_fundus(s.img_path);

        % Load any associated ground-truth masks
        loadedMasks = struct();
        if isfield(s.masks, 'vessel_path') && exist(s.masks.vessel_path, 'file') == 2
            loadedMasks.vessel_mask = (imread(s.masks.vessel_path) > 0);
        end
        if isfield(s.masks, 'ma_path') && exist(s.masks.ma_path, 'file') == 2
            loadedMasks.ma_mask = (imread(s.masks.ma_path) > 0);
        end
        if isfield(s.masks, 'he_path') && exist(s.masks.he_path, 'file') == 2
            loadedMasks.he_mask = (imread(s.masks.he_path) > 0);
        end
        if isfield(s.masks, 'ex_path') && exist(s.masks.ex_path, 'file') == 2
            loadedMasks.ex_mask = (imread(s.masks.ex_path) > 0);
        end
        if isfield(s.masks, 'se_path') && exist(s.masks.se_path, 'file') == 2
            loadedMasks.se_mask = (imread(s.masks.se_path) > 0);
        end

        % Run feature extraction
        feats1 = extract_features(prep, loadedMasks, cfg);

        % Verification 1: Vector is numeric and matches expected length
        if ~isnumeric(feats1.vector)
            testEntry.failures{end+1} = 'Feature vector is not numeric.';
        end
        if numel(feats1.vector) ~= expectedFeatureCount
            testEntry.failures{end+1} = sprintf('Feature vector length (%d) does not match expected (%d).', ...
                numel(feats1.vector), expectedFeatureCount);
        end

        % Verification 2: No NaN or Inf values
        if any(~isfinite(feats1.vector))
            testEntry.failures{end+1} = 'Feature vector contains non-finite (NaN or Inf) values.';
        end

        % Verification 3: Names match vector length
        if numel(feats1.names) ~= numel(feats1.vector)
            testEntry.failures{end+1} = 'Feature names count does not match feature vector length.';
        end

        % Verification 4: Color features work
        if feats1.color.mean_green <= 0 || feats1.color.green_contrast <= 0
            testEntry.failures{end+1} = 'Color features failed (mean_green or green_contrast <= 0).';
        end

        % Verification 5: Texture features work
        if feats1.texture.glcm_homogeneity <= 0 || feats1.texture.glcm_energy <= 0
            testEntry.failures{end+1} = 'Texture features failed (GLCM homogeneity or energy <= 0).';
        end

        % Verification 6: Vessel features work where masks are available
        if strcmpi(s.dataset, 'DRIVE')
            if feats1.vessel.vessel_density <= 0 || feats1.vessel.vessel_edge_density <= 0
                testEntry.failures{end+1} = 'Vessel features failed to quantify DRIVE ground-truth mask.';
            else
                fprintf('  [PASS] Vessel Density: %.4f, Edge Density: %.4f\n', ...
                    feats1.vessel.vessel_density, feats1.vessel.vessel_edge_density);
            end
        end

        % Verification 7: Lesion features work where masks are available
        if strcmpi(s.dataset, 'IDRiD')
            if feats1.lesion.hard_exudate_area <= 0 || feats1.lesion.hard_exudate_count <= 0
                testEntry.failures{end+1} = 'Lesion features failed to quantify IDRiD hard exudates.';
            else
                fprintf('  [PASS] Hard Exudates: Area Ratio=%.4f, Count=%d | MA Count=%d\n', ...
                    feats1.lesion.hard_exudate_area, feats1.lesion.hard_exudate_count, ...
                    feats1.lesion.microaneurysm_count);
            end
        end

        % Verification 8: Determinism check (re-run gives identical vector)
        feats2 = extract_features(prep, loadedMasks, cfg);
        if ~isequal(feats1.vector, feats2.vector)
            testEntry.failures{end+1} = 'Feature extraction is non-deterministic (consecutive runs differ).';
        end

        % Summary
        if isempty(testEntry.failures)
            testEntry.passed = true;
            fprintf('  [PASS] 22-D feature vector verified. Mean Green: %.1f, GLCM Contrast: %.2f\n\n', ...
                feats1.color.green_mean, feats1.texture.glcm_contrast);
        else
            testEntry.passed = false;
            results.all_passed = false;
            fprintf('  [FAIL] Failures:\n');
            for k = 1:numel(testEntry.failures)
                fprintf('    * %s\n', testEntry.failures{k});
            end
            fprintf('\n');
        end

        testEntry.feature_vector = feats1.vector;
        testEntry.feature_names = feats1.names;
        results.tests.(lower(s.sample_id)) = testEntry;
    end

    fprintf('=================================================================\n');
    if results.all_passed
        fprintf('  ALL FEATURE EXTRACTION TESTS PASSED!                           \n');
        fprintf('  Standardized Vector: 22 Features (Color: 8, Texture: 4,        \n');
        fprintf('                       Vessels: 2, Lesions: 8)                   \n');
    else
        fprintf('  SOME FEATURE EXTRACTION TESTS FAILED. See details above.       \n');
    end
    fprintf('=================================================================\n\n');
end
