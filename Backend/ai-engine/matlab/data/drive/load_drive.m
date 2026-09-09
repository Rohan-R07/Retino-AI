function [datasetTable, statusReport] = load_drive(customConfig)
% LOAD_DRIVE Loads and audits the Digital Retinal Images for Vessel Extraction (DRIVE) dataset
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Structure in DRIVE:
%   - Training (20 images): images, 1st_manual vessel ground truth masks, FOV masks
%   - Test (20 images): images, FOV masks (note: manual vessel masks are reserved for training evaluation)
%
% Output:
%   datasetTable - Standardized MATLAB table with vessel_mask_path & fov_mask_path
%   statusReport - Struct with counts and validation status

    if nargin < 1 || isempty(customConfig)
        cfg = dataset_config();
        driveCfg = cfg.drive;
    elseif isfield(customConfig, 'drive')
        driveCfg = customConfig.drive;
    else
        driveCfg = customConfig;
    end

    statusReport = struct();
    statusReport.dataset = 'drive';
    statusReport.is_available = false;
    statusReport.num_images_found = 0;
    statusReport.training_images_found = 0;
    statusReport.training_vessel_masks_found = 0;
    statusReport.training_fov_masks_found = 0;
    statusReport.test_images_found = 0;
    statusReport.test_fov_masks_found = 0;
    statusReport.missing_vessel_masks = {};
    statusReport.missing_fov_masks = {};
    statusReport.message = '';

    datasetTable = create_standard_table();

    rootPath = driveCfg.root;
    if isempty(rootPath) || exist(rootPath, 'dir') ~= 7
        statusReport.message = sprintf('DRIVE root directory not found: %s', rootPath);
        return;
    end

    foundImages = {};
    foundVesselMasks = {};
    foundFovMasks = {};
    foundSplits = {};
    foundIds = {};

    % 1. Audit Training Set
    trImgDir = fullfile(rootPath, 'training', 'images');
    trVesselDir = fullfile(rootPath, 'training', '1st_manual');
    trFovDir = fullfile(rootPath, 'training', 'mask');

    if exist(trImgDir, 'dir') == 7
        trFiles = dir(fullfile(trImgDir, '*.tif'));
        statusReport.training_images_found = numel(trFiles);

        for i = 1:numel(trFiles)
            fn = trFiles(i).name;
            [~, baseId, ~] = fileparts(fn);
            parts = strsplit(baseId, '_');
            numId = parts{1};

            fullImg = fullfile(trImgDir, fn);

            % Vessel mask: 21_manual1.gif
            vMask = fullfile(trVesselDir, [numId, '_manual1.gif']);
            if exist(vMask, 'file') ~= 2
                vMask = fullfile(trVesselDir, [baseId, '.gif']);
            end
            if exist(vMask, 'file') ~= 2
                vMask = '';
                statusReport.missing_vessel_masks{end+1} = baseId;
            else
                statusReport.training_vessel_masks_found = statusReport.training_vessel_masks_found + 1;
            end

            % FOV mask: 21_training_mask.gif
            fMask = fullfile(trFovDir, [baseId, '_mask.gif']);
            if exist(fMask, 'file') ~= 2
                fMask = fullfile(trFovDir, [numId, '_training_mask.gif']);
            end
            if exist(fMask, 'file') ~= 2
                fMask = '';
                statusReport.missing_fov_masks{end+1} = baseId;
            else
                statusReport.training_fov_masks_found = statusReport.training_fov_masks_found + 1;
            end

            foundImages{end+1} = fullImg; %#ok<AGROW>
            foundVesselMasks{end+1} = vMask; %#ok<AGROW>
            foundFovMasks{end+1} = fMask; %#ok<AGROW>
            foundSplits{end+1} = 'train'; %#ok<AGROW>
            foundIds{end+1} = ['drive_train_', numId]; %#ok<AGROW>
        end
    end

    % 2. Audit Test Set
    tsImgDir = fullfile(rootPath, 'test', 'images');
    tsFovDir = fullfile(rootPath, 'test', 'mask');

    if exist(tsImgDir, 'dir') == 7
        tsFiles = dir(fullfile(tsImgDir, '*.tif'));
        statusReport.test_images_found = numel(tsFiles);

        for i = 1:numel(tsFiles)
            fn = tsFiles(i).name;
            [~, baseId, ~] = fileparts(fn);
            parts = strsplit(baseId, '_');
            numId = parts{1};

            fullImg = fullfile(tsImgDir, fn);

            % In standard DRIVE, test images do not have 1st_manual annotations
            vMask = '';

            % FOV mask: 01_test_mask.gif
            fMask = fullfile(tsFovDir, [baseId, '_mask.gif']);
            if exist(fMask, 'file') ~= 2
                fMask = fullfile(tsFovDir, [numId, '_test_mask.gif']);
            end
            if exist(fMask, 'file') ~= 2
                fMask = '';
                statusReport.missing_fov_masks{end+1} = baseId;
            else
                statusReport.test_fov_masks_found = statusReport.test_fov_masks_found + 1;
            end

            foundImages{end+1} = fullImg; %#ok<AGROW>
            foundVesselMasks{end+1} = vMask; %#ok<AGROW>
            foundFovMasks{end+1} = fMask; %#ok<AGROW>
            foundSplits{end+1} = 'test'; %#ok<AGROW>
            foundIds{end+1} = ['drive_test_', numId]; %#ok<AGROW>
        end
    end

    totalImages = numel(foundImages);
    statusReport.num_images_found = totalImages;

    if totalImages > 0
        stdTable = create_standard_table(totalImages);
        for i = 1:totalImages
            stdTable.image_id(i) = string(foundIds{i});
            stdTable.image_path(i) = string(foundImages{i});
            stdTable.dataset(i) = "drive";
            stdTable.dr_grade(i) = NaN;
            stdTable.has_dr_label(i) = false;
            stdTable.lesion_mask_path(i) = "";
            stdTable.vessel_mask_path(i) = string(foundVesselMasks{i});
            stdTable.fov_mask_path(i) = string(foundFovMasks{i});
            stdTable.split(i) = string(foundSplits{i});
        end
        datasetTable = stdTable;
        statusReport.is_available = true;
        statusReport.message = sprintf('DRIVE verified: %d train images (%d vessel masks, %d FOV masks), %d test images (%d FOV masks).', ...
            statusReport.training_images_found, statusReport.training_vessel_masks_found, statusReport.training_fov_masks_found, ...
            statusReport.test_images_found, statusReport.test_fov_masks_found);
    else
        statusReport.message = sprintf('No DRIVE images found in %s', rootPath);
    end
end
