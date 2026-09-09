function [datasetTable, statusReport] = load_messidor2(customConfig)
% LOAD_MESSIDOR2 Loads the Messidor-2 dataset for external validation (OPTIONAL)
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Purpose: External evaluation and generalization testing.
% Note: Messidor-2 is optional, kept strictly independently identifiable, and NOT mixed into training.
%
% Output:
%   datasetTable - Standardized MATLAB table
%   statusReport - Struct with counts and status

    if nargin < 1 || isempty(customConfig)
        cfg = dataset_config();
        messidorCfg = cfg.messidor2;
    elseif isfield(customConfig, 'messidor2')
        messidorCfg = customConfig.messidor2;
    else
        messidorCfg = customConfig;
    end

    statusReport = struct();
    statusReport.dataset = 'messidor2';
    statusReport.is_available = false;
    statusReport.is_optional = true;
    statusReport.num_images_found = 0;
    statusReport.num_labels_found = 0;
    statusReport.num_matched = 0;
    statusReport.missing_images = {};
    statusReport.invalid_labels = [];
    statusReport.message = 'Messidor-2 is optional and currently not downloaded.';

    datasetTable = create_standard_table();

    % Check if enabled
    if isfield(messidorCfg, 'enabled') && ~messidorCfg.enabled
        statusReport.status = 'SKIPPED (Optional - not downloaded yet)';
        return;
    end

    rootPath = messidorCfg.root;
    if isempty(rootPath) || exist(rootPath, 'dir') ~= 7
        statusReport.status = 'NOT CONFIGURED / MISSING';
        return;
    end

    % Locate labels file (CSV, Excel)
    labelFile = messidorCfg.labels;
    if isempty(labelFile)
        candidateLabels = {
            fullfile(rootPath, 'messidor_data.csv'), ...
            fullfile(rootPath, 'messidor2_dr_grades.csv'), ...
            fullfile(rootPath, 'labels.csv'), ...
            fullfile(rootPath, 'messidor2.csv')
        };
        for i = 1:numel(candidateLabels)
            if exist(candidateLabels{i}, 'file') == 2
                labelFile = candidateLabels{i};
                break;
            end
        end
    end

    % Locate images directory
    imgDir = messidorCfg.images;
    if isempty(imgDir)
        candidateDirs = {
            fullfile(rootPath, 'images'), ...
            fullfile(rootPath, 'IMAGES'), ...
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

    hasLabels = (~isempty(labelFile) && exist(labelFile, 'file') == 2);
    supportedExts = {'.jpg', '.jpeg', '.png', '.tif', '.tiff'};

    if hasLabels
        try
            opts = detectImportOptions(labelFile);
            rawTable = readtable(labelFile, opts);
        catch ME
            statusReport.message = sprintf('Error reading Messidor-2 labels: %s', ME.message);
            statusReport.status = 'READ_ERROR';
            return;
        end

        varNames = lower(rawTable.Properties.VariableNames);
        idColIdx = find(contains(varNames, 'image') | contains(varNames, 'id') | contains(varNames, 'name'));
        gradeColIdx = find(contains(varNames, 'adjudicated') | contains(varNames, 'grade') | contains(varNames, 'dr') | contains(varNames, 'retinopathy'));

        if isempty(idColIdx) || isempty(gradeColIdx)
            statusReport.status = 'SCHEMA_MISMATCH';
            return;
        end

        idColName = rawTable.Properties.VariableNames{idColIdx(1)};
        gradeColName = rawTable.Properties.VariableNames{gradeColIdx(1)};

        rawIds = rawTable.(idColName);
        rawGrades = rawTable.(gradeColName);
        numRows = numel(rawIds);
        statusReport.num_labels_found = numRows;

        stdTable = create_standard_table(numRows);
        validEntries = false(numRows, 1);
        missingList = {};
        invalidGradeList = [];

        for i = 1:numRows
            if iscell(rawIds)
                currId = strtrim(char(rawIds{i}));
            else
                currId = strtrim(char(string(rawIds(i))));
            end

            if iscell(rawGrades)
                currGrade = str2double(rawGrades{i});
            else
                currGrade = double(rawGrades(i));
            end

            if isnan(currGrade) || currGrade < 0 || currGrade > 4
                invalidGradeList = [invalidGradeList; i]; %#ok<AGROW>
                continue;
            end

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

            stdTable.image_id(i) = string(currId);
            stdTable.image_path(i) = string(matchedPath);
            stdTable.dataset(i) = "messidor2";
            stdTable.dr_grade(i) = currGrade;
            stdTable.has_dr_label(i) = true;
            stdTable.lesion_mask_path(i) = "";
            stdTable.vessel_mask_path(i) = "";
            stdTable.fov_mask_path(i) = "";
            stdTable.split(i) = "test";

            validEntries(i) = true;
        end

        datasetTable = stdTable(validEntries, :);
        statusReport.num_matched = height(datasetTable);
        statusReport.num_images_found = height(datasetTable);
        statusReport.missing_images = missingList;
        statusReport.invalid_labels = invalidGradeList;
        statusReport.is_available = (height(datasetTable) > 0);
        statusReport.status = 'READY';
    else
        statusReport.status = 'SKIPPED (Optional - labels not present)';
    end
end
