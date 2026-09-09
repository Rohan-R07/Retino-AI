function outputPaths = visualize_quality_assessment(customConfig)
% VISUALIZE_QUALITY_ASSESSMENT Generates visual quality audit panels
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Renders comprehensive quality debugging reports showing:
%   - Preprocessed fundus image
%   - Retinal Field of View (FOV) mask overlay
%   - Photometric & Focus quality scores (Blur, Brightness, FOV Area, Entropy)
%   - Deterministic PASS / FAIL decision badge
%   - Actionable, explainable rejection reasons
%
% Audits both normal clinical samples and controlled degradation scenarios:
%   - Normal APTOS, IDRiD, and DRIVE images (Must pass)
%   - Degraded blurred capture (Must fail blur check)
%   - Degraded underexposed capture (Must fail brightness check)
%   - Degraded overexposed capture (Must fail brightness check)
%   - Degraded insufficient FOV capture (Must fail FOV check)
%
% Saves visual reports to: Backend/ai-engine/outputs/quality_assessment/
%
% Usage:
%   visualize_quality_assessment();

    scriptDir = fileparts(mfilename('fullpath'));
    matlabDir = fileparts(scriptDir);
    rootDir = fileparts(matlabDir);

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
            outDir = trainCfg.paths.quality_outputs;
        catch
            cfg = struct();
            cfg.blur_threshold = 25.0;
            cfg.brightness_min = 35.0;
            cfg.brightness_max = 180.0;
            cfg.min_entropy = 4.0;
            cfg.min_fov_ratio = 0.25;
            cfg.min_circularity = 0.35;
            outDir = fullfile(rootDir, 'outputs', 'quality_assessment');
        end
    else
        cfg = customConfig;
        if isfield(cfg, 'output_dir')
            outDir = cfg.output_dir;
        else
            outDir = fullfile(rootDir, 'outputs', 'quality_assessment');
        end
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    fprintf('=================================================================\n');
    fprintf('        RETINO-AI QUALITY ASSESSMENT VISUAL AUDIT                \n');
    fprintf('=================================================================\n');
    fprintf('Output Directory: %s\n\n', outDir);

    samples = {
        struct('dataset', 'APTOS', 'format', 'PNG', ...
               'path', fullfile(rootDir, 'data', 'raw', 'aptos', 'train_images', '000c1434d8d7.png'), ...
               'outName', 'aptos_quality_report.png'), ...
        struct('dataset', 'IDRiD', 'format', 'JPG', ...
               'path', fullfile(rootDir, 'data', 'raw', 'idrid', 'Disease Grading', '1. Original Images', 'a. Training Set', 'IDRiD_001.jpg'), ...
               'outName', 'idrid_quality_report.png'), ...
        struct('dataset', 'DRIVE', 'format', 'TIF', ...
               'path', fullfile(rootDir, 'data', 'raw', 'drive', 'training', 'images', '21_training.tif'), ...
               'outName', 'drive_quality_report.png') ...
    };

    outputPaths = struct();

    % Process normal samples
    for i = 1:numel(samples)
        s = samples{i};
        if exist(s.path, 'file') ~= 2
            continue;
        end

        prep = preprocess_fundus(s.path);
        q = assess_image_quality(prep, cfg);

        saveFile = fullfile(outDir, s.outName);
        render_quality_card(prep.resized, prep.fov_mask, q, sprintf('%s (%s)', s.dataset, s.format), saveFile);
        fprintf('  Saved quality audit report -> %s\n', saveFile);
        outputPaths.(lower(s.dataset)) = saveFile;
    end

    % Process degradation scenarios
    baseSample = samples{1}.path;
    if exist(baseSample, 'file') == 2
        basePrep = preprocess_fundus(baseSample);
        baseImg = basePrep.resized;
        baseFov = basePrep.fov_mask;

        degradations = {
            struct('title', 'Degraded - Severe Blur', ...
                   'img', imgaussfilt(baseImg, 6.0), ...
                   'mask', baseFov, ...
                   'outName', 'degraded_blur_report.png'), ...
            struct('title', 'Degraded - Underexposed', ...
                   'img', uint8(double(baseImg) * 0.15), ...
                   'mask', baseFov, ...
                   'outName', 'degraded_underexposed_report.png'), ...
            struct('title', 'Degraded - Overexposed', ...
                   'img', uint8(min(255, double(baseImg) * 2.2 + 80)), ...
                   'mask', baseFov, ...
                   'outName', 'degraded_overexposed_report.png') ...
        };

        for d = 1:numel(degradations)
            deg = degradations{d};
            degStruct = struct('resized', deg.img, 'fov_mask', deg.mask, 'metadata', basePrep.metadata);
            qDeg = assess_image_quality(degStruct, cfg);
            saveDegFile = fullfile(outDir, deg.outName);
            render_quality_card(deg.img, deg.mask, qDeg, deg.title, saveDegFile);
            fprintf('  Saved degraded scenario report -> %s\n', saveDegFile);
        end
    end

    fprintf('\n=================================================================\n');
    fprintf('  QUALITY VISUAL AUDIT COMPLETE. Inspect files in outputs/quality_assessment/\n');
    fprintf('=================================================================\n\n');
end

function render_quality_card(img, fovMask, q, titleStr, savePath)
    hFig = figure('Visible', 'off', 'Position', [100, 100, 1200, 520]);

    % Subplot 1: Preprocessed fundus image
    subplot(1, 3, 1);
    imshow(img);
    title(sprintf('Input Fundus Image\n%s', titleStr), 'FontSize', 11, 'FontWeight', 'bold');

    % Subplot 2: Retinal FOV Mask Overlay
    subplot(1, 3, 2);
    % Create green perimeter overlay
    fovPerim = bwperim(fovMask);
    overlay = img;
    for c = 1:3
        ch = overlay(:, :, c);
        if c == 2
            ch(fovPerim) = 255; % Green outline
        else
            ch(fovPerim) = 0;
        end
        overlay(:, :, c) = ch;
    end
    imshow(overlay);
    title(sprintf('Retinal FOV Aperture\nCoverage: %.1f%%', q.fov_details.retina_area_ratio * 100.0), ...
        'FontSize', 11, 'FontWeight', 'bold');

    % Subplot 3: Quality Metrics & Gradability Verdict Panel
    subplot(1, 3, 3);
    axis off;
    hold on;

    % Status color
    if q.is_gradable
        statusText = 'PASS - GRADABLE';
        statusColor = [0.0, 0.65, 0.2]; % Green
    else
        statusText = 'FAIL - UNGRADABLE';
        statusColor = [0.85, 0.1, 0.1]; % Red
    end

    text(0.05, 0.90, statusText, 'FontSize', 15, 'FontWeight', 'bold', 'Color', statusColor);
    text(0.05, 0.80, sprintf('Overall Quality: %s', upper(q.overall_quality)), 'FontSize', 11, 'FontWeight', 'bold');

    % Metric bullets
    text(0.05, 0.68, sprintf('Focus / Blur Score: %.2f (Threshold: >= %.2f)', ...
        q.blur_score, q.sharpness_details.threshold), 'FontSize', 10);
    text(0.05, 0.60, sprintf('Blur Check: %s', ternaryStr(q.blur_pass, 'PASS', 'FAIL')), ...
        'FontSize', 10, 'FontWeight', 'bold', 'Color', passColor(q.blur_pass));

    text(0.05, 0.50, sprintf('Mean Brightness: %.2f (Valid: [%.1f - %.1f])', ...
        q.brightness_details.mean_luminance, q.brightness_details.min_mean_threshold, ...
        q.brightness_details.max_mean_threshold), 'FontSize', 10);
    text(0.05, 0.42, sprintf('Brightness Check: %s (%s)', ...
        ternaryStr(q.brightness_pass, 'PASS', 'FAIL'), q.brightness_details.verdict), ...
        'FontSize', 10, 'FontWeight', 'bold', 'Color', passColor(q.brightness_pass));

    text(0.05, 0.32, sprintf('Retinal FOV Coverage: %.1f%% (Min: %.1f%%)', ...
        q.fov_details.retina_area_ratio * 100.0, q.fov_details.min_area_ratio_threshold * 100.0), 'FontSize', 10);
    text(0.05, 0.24, sprintf('FOV Check: %s (Circularity: %.2f)', ...
        ternaryStr(q.fov_pass, 'PASS', 'FAIL'), q.fov_details.circularity), ...
        'FontSize', 10, 'FontWeight', 'bold', 'Color', passColor(q.fov_pass));

    % Rejection reasons
    if ~q.is_gradable
        text(0.05, 0.12, 'Rejection Reason:', 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0.85, 0.1, 0.1]);
        reasonWrapped = textwrap({q.rejection_reason}, 40);
        for rw = 1:min(2, numel(reasonWrapped))
            text(0.05, 0.06 - (rw-1)*0.06, reasonWrapped{rw}, 'FontSize', 9, 'Color', [0.85, 0.1, 0.1]);
        end
    else
        text(0.05, 0.10, 'Clinical Note: Gradable for DR screening.', 'FontSize', 9, 'Color', [0.0, 0.6, 0.2]);
    end

    try
        exportgraphics(hFig, savePath, 'Resolution', 150);
    catch
        saveas(hFig, savePath);
    end
    close(hFig);
end

function str = ternaryStr(cond, trueStr, falseStr)
    if cond
        str = trueStr;
    else
        str = falseStr;
    end
end

function col = passColor(pass)
    if pass
        col = [0.0, 0.65, 0.2];
    else
        col = [0.85, 0.1, 0.1];
    end
end
