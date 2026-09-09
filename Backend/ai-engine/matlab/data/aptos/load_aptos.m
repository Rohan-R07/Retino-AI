function [datasetTable, statusReport] = load_aptos(customConfig)
% LOAD_APTOS Loads and standardizes the APTOS 2019 Blindness Detection dataset
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Tasks: 5-Class DR Severity Classification (0=No DR, 1=Mild, 2=Moderate, 3=Severe, 4=Proliferative)
%
% Output:
%   datasetTable - Standardized MATLAB table (image_id, image_path, dataset, dr_grade, etc.)
%   statusReport - Struct containing image counts, label verification, and warnings

    if nargin < 1 || isempty(customConfig)
        cfg = dataset_config();
        aptosCfg = cfg.aptos;
    elseif isfield(customConfig, 'aptos')
        aptosCfg = customConfig.aptos;
    else
        aptosCfg = customConfig;
    end

    statusReport = struct();
    statusReport.dataset = 'aptos';
    statusReport.is_available = false;
    statusReport.num_images_found = 0;
    statusReport.num_labels_found = 0;
    statusReport.num_matched = 0;
    statusReport.missing_images = {};
    statusReport.invalid_labels = [];
    statusReport.message = '';

    datasetTable = create_standard_table();

    rootPath = aptosCfg.root;
    if isempty(rootPath) || exist(rootPath, 'dir') ~= 7
        statusReport.message = sprintf('APTOS root directory not found: %s', rootPath);
        return;
    end

    % Locate labels CSV (configured or standard variants)
    labelFile = aptosCfg.labels;
    if isempty(labelFile)
        candidateFiles = {
            fullfile(rootPath, 'train.csv'), ...
            fullfile(rootPath, 'labels.csv'), ...
            fullfile(rootPath, 'train_labels.csv')
        };
        for i = 1:numel(candidateFiles)
            if exist(candidateFiles{i}, 'file') == 2
                labelFile = candidateFiles{i};
                break;
            end
        end
    end

    if isempty(labelFile) || exist(labelFile, 'file') ~= 2
        statusReport.message = sprintf('APTOS label CSV not found in: %s', rootPath);
        warning('RetinoAI:APTOSMissingLabels', statusReport.message);
        return;
    end

    % Locate images directory
    imgDir = aptosCfg.images;
    if isempty(imgDir)
        candidateDirs = {
            fullfile(rootPath, 'train_images'), ...
            fullfile(rootPath, 'images'), ...
            rootPath
        };
        for i = 1:numel(candidateDirs)
            if exist(candidateDirs{i}, 'dir') == 7 && ~isequal(candidateDirs{i}, rootPath)
                imgDir = candidateDirs{i};
                break;
            end
        end
        if isempty(imgDir)
            imgDir = rootPath;
        end
    end

    % Read labels table
    try
        opts = detectImportOptions(labelFile);
        rawTable = readtable(labelFile, opts);
    catch ME
        statusReport.message = sprintf('Error reading label CSV %s: %s', labelFile, ME.message);
        warning('RetinoAI:APTOSReadError', statusReport.message);
        return;
    end

    % Resolve column names (id_code, diagnosis)
    varNames = lower(rawTable.Properties.VariableNames);
    idColIdx = find(contains(varNames, 'id') | contains(varNames, 'image'));
    diagColIdx = find(contains(varNames, 'diagnosis') | contains(varNames, 'grade') | contains(varNames, 'level') | contains(varNames, 'label'));

    if isempty(idColIdx) || isempty(diagColIdx)
        statusReport.message = 'Could not locate image ID and diagnosis columns in APTOS labels.';
        warning('RetinoAI:APTOSSchemaError', statusReport.message);
        return;
    end

    idColName = rawTable.Properties.VariableNames{idColIdx(1)};
    diagColName = rawTable.Properties.VariableNames{diagColIdx(1)};

    rawIds = rawTable.(idColName);
    rawLabels = rawTable.(diagColName);

    numRows = numel(rawIds);
    statusReport.num_labels_found = numRows;

    % Build standardized table
    validEntries = false(numRows, 1);
    stdTable = create_standard_table(numRows);
    missingList = {};
    invalidGradeList = [];

    supportedExts = {'.png', '.jpg', '.jpeg', '.tif', '.tiff'};

    for i = 1:numRows
        % Extract ID string
        if iscell(rawIds)
            currId = strtrim(char(rawIds{i}));
        elseif isstring(rawIds)
            currId = strtrim(char(rawIds(i)));
        else
            currId = num2str(rawIds(i));
        end

        % Extract numeric label
        if iscell(rawLabels)
            currGrade = str2double(rawLabels{i});
        else
            currGrade = double(rawLabels(i));
        end

        % Validate grade range 0-4
        if isnan(currGrade) || currGrade < 0 || currGrade > 4 || floor(currGrade) ~= currGrade
            invalidGradeList = [invalidGradeList; i]; %#ok<AGROW>
            continue;
        end

        % Locate image file on disk
        matchedPath = '';
        [~, ~, ext] = fileparts(currId);
        if ~isempty(ext)
            cand = fullfile(imgDir, currId);
            if exist(cand, 'file') == 2
                matchedPath = cand;
            end
        else
            for e = 1:numel(supportedExts)
                cand = fullfile(imgDir, [currId, supportedExts{e}]);
                if exist(cand, 'file') == 2
                    matchedPath = cand;
                    break;
                end
            end
        end

        if isempty(matchedPath)
            missingList{end+1} = currId; %#ok<AGROW>
            continue;
        end

        % Populate standard entry
        stdTable.image_id(i) = string(currId);
        stdTable.image_path(i) = string(matchedPath);
        stdTable.dataset(i) = "aptos";
        stdTable.dr_grade(i) = currGrade;
        stdTable.has_dr_label(i) = true;
        stdTable.lesion_mask_path(i) = "";
        stdTable.vessel_mask_path(i) = "";
        stdTable.fov_mask_path(i) = "";
        stdTable.split(i) = "unassigned";

        validEntries(i) = true;
    end

    datasetTable = stdTable(validEntries, :);

    statusReport.is_available = (height(datasetTable) > 0);
    statusReport.num_images_found = height(datasetTable);
    statusReport.num_matched = height(datasetTable);
    statusReport.missing_images = missingList;
    statusReport.invalid_labels = invalidGradeList;

    if ~isempty(missingList)
        warning('RetinoAI:APTOSMissingImages', ...
            '%d referenced images in APTOS could not be found in %s.', numel(missingList), imgDir);
    end
    if ~isempty(invalidGradeList)
        warning('RetinoAI:APTOSInvalidLabels', ...
            '%d labels in APTOS had values outside the valid range [0-4].', numel(invalidGradeList));
    end

    statusReport.message = sprintf('APTOS loaded: %d matched images (out of %d labels).', ...
        statusReport.num_matched, statusReport.num_labels_found);
end
