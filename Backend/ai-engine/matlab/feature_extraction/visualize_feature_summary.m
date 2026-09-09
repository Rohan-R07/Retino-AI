function savePath = visualize_feature_summary(sampleId, customConfig)
% VISUALIZE_FEATURE_SUMMARY Generates concise feature summary for a sample IDRiD image
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Visualizes:
%   1. Preprocessed Retinal Image (IDRiD)
%   2. Multi-lesion Ground-Truth Evidence Overlay (EX, HE, MA)
%   3. Extracted 22-Dimensional Feature Descriptors Table/Panel
%
% Output:
%   Saves artifact to: Backend/ai-engine/outputs/features/idrid_feature_summary.png
%
% Usage:
%   visualize_feature_summary();
%   visualize_feature_summary('IDRiD_01');

    scriptDir = fileparts(mfilename('fullpath'));
    matlabDir = fileparts(scriptDir);
    rootDir = fileparts(matlabDir);

    if exist(fullfile(matlabDir, 'setup_paths.m'), 'file') == 2
        run(fullfile(matlabDir, 'setup_paths.m'));
    else
        addpath(genpath(matlabDir));
        addpath(fullfile(rootDir, 'config'));
    end

    if nargin < 1 || isempty(sampleId)
        sampleId = 'IDRiD_01';
    end

    try
        trainCfg = training_config();
        outDir = trainCfg.paths.feature_outputs;
    catch
        outDir = fullfile(rootDir, 'outputs', 'features');
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % Locate image and lesion masks for the sample
    imgFile = fullfile(rootDir, 'data', 'raw', 'idrid', 'Segmentation', ...
        '1. Original Images', 'a. Training Set', sprintf('%s.jpg', sampleId));
    gtBase = fullfile(rootDir, 'data', 'raw', 'idrid', 'Segmentation', ...
        '2. All Segmentation Groundtruths', 'a. Training Set');

    maFile = fullfile(gtBase, '1. Microaneurysms', sprintf('%s_MA.tif', sampleId));
    heFile = fullfile(gtBase, '2. Haemorrhages', sprintf('%s_HE.tif', sampleId));
    exFile = fullfile(gtBase, '3. Hard Exudates', sprintf('%s_EX.tif', sampleId));
    seFile = fullfile(gtBase, '4. Soft Exudates', sprintf('%s_SE.tif', sampleId));

    if exist(imgFile, 'file') ~= 2
        error('RetinoAI:SampleNotFound', 'IDRiD sample image not found: %s', imgFile);
    end

    % Preprocess fundus image
    prep = preprocess_fundus(imgFile);

    % Load lesion masks
    masks = struct();
    if exist(maFile, 'file') == 2, masks.ma_mask = (imread(maFile) > 0); end
    if exist(heFile, 'file') == 2, masks.he_mask = (imread(heFile) > 0); end
    if exist(exFile, 'file') == 2, masks.ex_mask = (imread(exFile) > 0); end
    if exist(seFile, 'file') == 2, masks.se_mask = (imread(seFile) > 0); end

    % Extract features
    feats = extract_features(prep, masks);

    % Create composite lesion overlay
    targetSize = size(prep.resized);
    targetH = targetSize(1);
    targetW = targetSize(2);

    overlay = prep.resized;
    % Hard exudates -> Bright Yellow [255, 255, 0]
    if isfield(masks, 'ex_mask')
        exR = imresize(masks.ex_mask, [targetH, targetW], 'nearest');
        overlay = apply_color_mask(overlay, exR, [255, 255, 0]);
    end
    % Haemorrhages -> Bright Red [255, 30, 30]
    if isfield(masks, 'he_mask')
        heR = imresize(masks.he_mask, [targetH, targetW], 'nearest');
        overlay = apply_color_mask(overlay, heR, [255, 30, 30]);
    end
    % Microaneurysms -> Bright Cyan [0, 255, 255]
    if isfield(masks, 'ma_mask')
        maR = imresize(masks.ma_mask, [targetH, targetW], 'nearest');
        overlay = apply_color_mask(overlay, maR, [0, 255, 255]);
    end

    % Render figure
    hFig = figure('Visible', 'off', 'Position', [100, 100, 1260, 520]);

    % Subplot 1: Retinal Image
    subplot(1, 3, 1);
    imshow(prep.resized);
    title(sprintf('1. Retinal Image\n%s (Standardized 512x512)', sampleId), ...
        'FontSize', 11, 'FontWeight', 'bold');

    % Subplot 2: Lesion Ground Truth Overlay
    subplot(1, 3, 2);
    imshow(overlay);
    title(sprintf('2. Lesion Evidence Overlay\nYellow: EX | Red: HE | Cyan: MA'), ...
        'FontSize', 11, 'FontWeight', 'bold');

    % Subplot 3: Extracted Feature Values
    subplot(1, 3, 3);
    axis off;
    hold on;

    text(0.05, 0.95, sprintf('Feature Summary: %s', sampleId), 'FontSize', 13, 'FontWeight', 'bold');
    text(0.05, 0.88, sprintf('Vector Dimension: %d Features (Double)', feats.num_features), ...
        'FontSize', 10, 'Color', [0.3, 0.4, 0.5]);

    % Group 1: Color
    text(0.05, 0.78, '[Color Features - 8]', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.1, 0.5, 0.8]);
    text(0.05, 0.72, sprintf('Mean RGB: [%.1f, %.1f, %.1f]', ...
        feats.color.mean_red, feats.color.mean_green, feats.color.mean_blue), 'FontSize', 9);
    text(0.05, 0.66, sprintf('Green Mean: %.1f | Green Contrast: %.1f', ...
        feats.color.green_mean, feats.color.green_contrast), 'FontSize', 9);

    % Group 2: Texture
    text(0.05, 0.56, '[Texture Features - 4]', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.2, 0.6, 0.3]);
    text(0.05, 0.50, sprintf('GLCM Contrast: %.2f | Correlation: %.3f', ...
        feats.texture.glcm_contrast, feats.texture.glcm_correlation), 'FontSize', 9);
    text(0.05, 0.44, sprintf('GLCM Energy: %.3f | Homogeneity: %.3f', ...
        feats.texture.glcm_energy, feats.texture.glcm_homogeneity), 'FontSize', 9);

    % Group 3: Vessels
    text(0.05, 0.34, '[Vessel Features - 2]', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.8, 0.4, 0.1]);
    text(0.05, 0.28, sprintf('Vessel Density: %.4f | Edge Density: %.4f', ...
        feats.vessel.vessel_density, feats.vessel.vessel_edge_density), 'FontSize', 9);

    % Group 4: Lesions
    text(0.05, 0.18, '[Lesion Evidence - 8]', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.8, 0.2, 0.2]);
    text(0.05, 0.12, sprintf('Hard Exudates: Area=%.4f (Count=%d)', ...
        feats.lesion.hard_exudate_area, feats.lesion.hard_exudate_count), 'FontSize', 9);
    text(0.05, 0.06, sprintf('Hemorrhages: Area=%.4f | MA Count: %d', ...
        feats.lesion.hemorrhage_area, feats.lesion.microaneurysm_count), 'FontSize', 9);

    savePath = fullfile(outDir, 'idrid_feature_summary.png');
    try
        exportgraphics(hFig, savePath, 'Resolution', 160);
    catch
        saveas(hFig, savePath);
    end
    close(hFig);

    fprintf('Saved feature summary visual to: %s\n', savePath);
end

function outImg = apply_color_mask(baseImg, binMask, rgbColor)
    outImg = baseImg;
    if isempty(binMask) || ~any(binMask(:)), return; end
    for c = 1:3
        ch = outImg(:, :, c);
        ch(binMask) = uint8(0.4 * double(ch(binMask)) + 0.6 * double(rgbColor(c)));
        outImg(:, :, c) = ch;
    end
end
