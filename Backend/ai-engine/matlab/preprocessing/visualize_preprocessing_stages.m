function outputPaths = visualize_preprocessing_stages(customConfig)
% VISUALIZE_PREPROCESSING_STAGES Generates multi-stage visual inspection artifacts
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Generates visual comparison images showing all 6 key preprocessing stages:
%   1. Original Raw Fundus Image
%   2. Retinal FOV Crop (Aperture isolated, dark borders removed)
%   3. Standardized Resized Image (512x512 prototype)
%   4. Green Channel Extraction (Optimal vascular & lesion contrast)
%   5. Illumination Normalization (Graham model background subtraction)
%   6. Contrast Enhancement (CLAHE in L*a*b* space)
%
% Tests 1 real image from each dataset:
%   - APTOS 2019 (PNG)
%   - IDRiD (JPG)
%   - DRIVE (TIF)
%
% Saves stage comparisons to: Backend/ai-engine/outputs/preprocessing/
%
% Usage:
%   visualize_preprocessing_stages();

    scriptDir = fileparts(mfilename('fullpath'));
    matlabDir = fileparts(scriptDir);
    rootDir = fileparts(matlabDir);

    % Ensure paths are loaded
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
            outDir = trainCfg.paths.preprocessing_outputs;
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
            outDir = fullfile(rootDir, 'outputs', 'preprocessing');
        end
    else
        cfg = customConfig;
        if isfield(cfg, 'output_dir')
            outDir = cfg.output_dir;
        else
            outDir = fullfile(rootDir, 'outputs', 'preprocessing');
        end
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    fprintf('=================================================================\n');
    fprintf('         FUNDUS PREPROCESSING VISUAL VERIFICATION                \n');
    fprintf('=================================================================\n');
    fprintf('Output Directory: %s\n\n', outDir);

    samples = {
        struct('dataset', 'APTOS', 'format', 'PNG', ...
               'path', fullfile(rootDir, 'data', 'raw', 'aptos', 'train_images', '000c1434d8d7.png'), ...
               'outName', 'aptos_stages.png'), ...
        struct('dataset', 'IDRiD', 'format', 'JPG', ...
               'path', fullfile(rootDir, 'data', 'raw', 'idrid', 'Disease Grading', '1. Original Images', 'a. Training Set', 'IDRiD_001.jpg'), ...
               'outName', 'idrid_stages.png'), ...
        struct('dataset', 'DRIVE', 'format', 'TIF', ...
               'path', fullfile(rootDir, 'data', 'raw', 'drive', 'training', 'images', '21_training.tif'), ...
               'outName', 'drive_stages.png') ...
    };

    outputPaths = struct();

    for i = 1:numel(samples)
        s = samples{i};
        fprintf('Processing %s (%s format)...\n', s.dataset, s.format);

        if exist(s.path, 'file') ~= 2
            % Fallback search
            if strcmpi(s.dataset, 'APTOS')
                cand = dir(fullfile(rootDir, 'data', 'raw', 'aptos', 'train_images', '*.png'));
            elseif strcmpi(s.dataset, 'IDRiD')
                cand = dir(fullfile(rootDir, 'data', 'raw', 'idrid', '**', '*.jpg'));
            else
                cand = dir(fullfile(rootDir, 'data', 'raw', 'drive', '**', '*.tif'));
            end
            if ~isempty(cand)
                s.path = fullfile(cand(1).folder, cand(1).name);
            else
                fprintf('  [SKIP] No sample found for %s.\n', s.dataset);
                continue;
            end
        end

        % Run full preprocessing pipeline
        res = preprocess_fundus(s.path, cfg);

        % Prepare the 6 visual stages
        % 1. Original (scaled to display size if too large)
        origDisp = res.original;
        maxDim = 512;
        if size(origDisp, 1) > maxDim || size(origDisp, 2) > maxDim
            origDisp = imresize(origDisp, [maxDim, maxDim], 'bicubic');
        end

        % 2. FOV Cropped
        croppedDisp = res.cropped;
        if size(croppedDisp, 1) ~= maxDim || size(croppedDisp, 2) ~= maxDim
            croppedDisp = imresize(croppedDisp, [maxDim, maxDim], 'bicubic');
        end

        % 3. Resized (512x512)
        resizedDisp = res.resized;

        % 4. Green Channel (converted to 3-channel for consistent montage)
        greenDisp = cat(3, res.green_channel, res.green_channel, res.green_channel);

        % 5. Normalized
        normDisp = res.normalized;

        % 6. Enhanced (CLAHE)
        enhancedDisp = res.enhanced;

        % Create a structured 2x3 side-by-side montage
        topRow = [origDisp, croppedDisp, resizedDisp];
        botRow = [greenDisp, normDisp, enhancedDisp];
        montageImg = [topRow; botRow];

        savePath = fullfile(outDir, s.outName);
        imwrite(montageImg, savePath);
        fprintf('  Saved montage to: %s\n', savePath);

        % Also render a labeled MATLAB figure with titles for interactive inspection
        hFig = figure('Visible', 'off', 'Position', [50, 50, 1500, 950]);
        stages = {
            origDisp,     sprintf('1. Original Raw (%s)\n[%dx%d]', s.format, res.metadata.original_size(1), res.metadata.original_size(2));
            croppedDisp,  sprintf('2. Retinal FOV Crop\nBBox: [%d,%d,%d,%d]', res.metadata.crop_bbox(1), res.metadata.crop_bbox(2), res.metadata.crop_bbox(3), res.metadata.crop_bbox(4));
            resizedDisp,  sprintf('3. Standardized Resize\n[%dx%d]', cfg.target_size(1), cfg.target_size(2));
            res.green_channel, sprintf('4. Green Channel\n(High Lesion Contrast)');
            normDisp,     sprintf('5. Normalized Illumination\n(Graham Background Subtraction)');
            enhancedDisp, sprintf('6. Contrast Enhanced\n(CLAHE L*a*b*)')
        };

        for subIdx = 1:6
            subplot(2, 3, subIdx);
            if size(stages{subIdx, 1}, 3) == 1
                imshow(stages{subIdx, 1}, []);
                colormap(gca, 'gray');
            else
                imshow(stages{subIdx, 1});
            end
            title(stages{subIdx, 2}, 'FontSize', 11, 'FontWeight', 'bold');
        end

        sgtitle(sprintf('Retino-AI Preprocessing Pipeline - %s Dataset Sample', s.dataset), ...
            'FontSize', 15, 'FontWeight', 'bold');

        figSavePath = fullfile(outDir, strrep(s.outName, '.png', '_labeled.png'));
        try
            exportgraphics(hFig, figSavePath, 'Resolution', 180);
        catch
            saveas(hFig, figSavePath);
        end
        close(hFig);
        fprintf('  Saved labeled figure to: %s\n\n', figSavePath);

        outputPaths.(lower(s.dataset)) = savePath;
        outputPaths.([lower(s.dataset) '_labeled']) = figSavePath;
    end

    fprintf('=================================================================\n');
    fprintf('  VISUAL VERIFICATION COMPLETE. Inspect images in outputs/preprocessing/\n');
    fprintf('=================================================================\n\n');
end
