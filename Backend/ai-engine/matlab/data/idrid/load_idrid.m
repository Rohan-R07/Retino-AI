function [datasetTable, statusReport] = load_idrid(customConfig)
% LOAD_IDRID Loads and audits the Indian Diabetic Retinopathy Image Dataset (IDRiD)
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Audits & Supports:
%   1. Disease Grading: Training (413) + Testing (103) with 5-class severity grades (0-4)
%   2. Segmentation: Training (54) + Testing (27) with pixel masks for:
%      - 1. Microaneurysms (MA)
%      - 2. Haemorrhages (HE)
%      - 3. Hard Exudates (EX)
%      - 4. Soft Exudates (SE)
%      - 5. Optic Disc (OD)
%   3. Localization: Optic Disc & Fovea Center coordinates (516 images total)
%
% Output:
%   datasetTable - Standardized MATLAB table of all disease grading images
%   statusReport - Detailed struct auditing Disease Grading, Segmentation, and Localization

    if nargin < 1 || isempty(customConfig)
        cfg = dataset_config();
        idridCfg = cfg.idrid;
    elseif isfield(customConfig, 'idrid')
        idridCfg = customConfig.idrid;
    else
        idridCfg = customConfig;
    end

    statusReport = struct();
    statusReport.dataset = 'idrid';
    statusReport.is_available = false;
    statusReport.has_disease_grading = false;
    statusReport.has_segmentation = false;
    statusReport.has_localization = false;
    
    statusReport.num_images_found = 0;
    statusReport.num_labels_found = 0;
    statusReport.num_matched = 0;
    statusReport.missing_images = {};
    statusReport.invalid_labels = [];
    statusReport.message = '';

    % Detailed sub-audit metrics
    statusReport.grading = struct('train_images', 0, 'train_labels', 0, 'test_images', 0, 'test_labels', 0);
    statusReport.segmentation = struct('train_images', 0, 'test_images', 0, 'masks_detected', struct());
    statusReport.localization = struct('od_train_rows', 0, 'od_test_rows', 0, 'fovea_train_rows', 0, 'fovea_test_rows', 0);

    datasetTable = create_standard_table();

    rootPath = idridCfg.root;
    if isempty(rootPath) || exist(rootPath, 'dir') ~= 7
        statusReport.message = sprintf('IDRiD root directory not found: %s', rootPath);
        return;
    end

    % =========================================================================
    % 1. DISEASE GRADING AUDIT & LOADING
    % =========================================================================
    gradingPairs = {
        struct('subset', 'train', ...
               'labels', idridCfg.grading_train_labels, ...
               'images', idridCfg.grading_train_images), ...
        struct('subset', 'test', ...
               'labels', idridCfg.grading_test_labels, ...
               'images', idridCfg.grading_test_images)
    };

    allSubTables = {};
    totalGradingMatched = 0;

    for p = 1:numel(gradingPairs)
        sub = gradingPairs{p}.subset;
        lblFile = gradingPairs{p}.labels;
        imgDir = gradingPairs{p}.images;

        if exist(lblFile, 'file') == 2 && exist(imgDir, 'dir') == 7
            try
                opts = detectImportOptions(lblFile);
                rawTbl = readtable(lblFile, opts);
            catch
                rawTbl = table();
            end

            if ~isempty(rawTbl) && width(rawTbl) >= 2
                varNames = lower(rawTbl.Properties.VariableNames);
                idIdx = find(contains(varNames, 'image') | contains(varNames, 'id'), 1);
                grIdx = find(contains(varNames, 'retinopathy') | contains(varNames, 'grade') | contains(varNames, 'dr'), 1);

                if ~isempty(idIdx) && ~isempty(grIdx)
                    idCol = rawTbl.Properties.VariableNames{idIdx};
                    grCol = rawTbl.Properties.VariableNames{grIdx};

                    rawIds = rawTbl.(idCol);
                    rawGrades = rawTbl.(grCol);
                    nRows = numel(rawIds);

                    if strcmp(sub, 'train')
                        statusReport.grading.train_labels = nRows;
                    else
                        statusReport.grading.test_labels = nRows;
                    end

                    subTable = create_standard_table(nRows);
                    validEntries = false(nRows, 1);

                    for i = 1:nRows
                        if iscell(rawIds)
                            cId = strtrim(char(rawIds{i}));
                        else
                            cId = strtrim(char(string(rawIds(i))));
                        end

                        if iscell(rawGrades)
                            cGrade = str2double(rawGrades{i});
                        else
                            cGrade = double(rawGrades(i));
                        end

                        candImg = fullfile(imgDir, [cId, '.jpg']);
                        if exist(candImg, 'file') ~= 2
                            candImg = fullfile(imgDir, [cId, '.tif']);
                        end

                        if exist(candImg, 'file') == 2 && ~isnan(cGrade) && cGrade >= 0 && cGrade <= 4
                            subTable.image_id(i) = string(sprintf('idrid_%s_%s', sub, cId));
                            subTable.image_path(i) = string(candImg);
                            subTable.dataset(i) = "idrid";
                            subTable.dr_grade(i) = cGrade;
                            subTable.has_dr_label(i) = true;
                            subTable.lesion_mask_path(i) = "";
                            subTable.vessel_mask_path(i) = "";
                            subTable.fov_mask_path(i) = "";
                            subTable.split(i) = string(sub);
                            validEntries(i) = true;
                        end
                    end

                    matchedTbl = subTable(validEntries, :);
                    if strcmp(sub, 'train')
                        statusReport.grading.train_images = height(matchedTbl);
                    else
                        statusReport.grading.test_images = height(matchedTbl);
                    end
                    allSubTables{end+1} = matchedTbl; %#ok<AGROW>
                    totalGradingMatched = totalGradingMatched + height(matchedTbl);
                end
            end
        end
    end

    if totalGradingMatched > 0
        datasetTable = vertcat(allSubTables{:});
        statusReport.has_disease_grading = true;
        statusReport.num_images_found = totalGradingMatched;
        statusReport.num_labels_found = statusReport.grading.train_labels + statusReport.grading.test_labels;
        statusReport.num_matched = totalGradingMatched;
    end

    % =========================================================================
    % 2. SEGMENTATION AUDIT
    % =========================================================================
    segTrainImgs = idridCfg.segmentation_train_images;
    segTestImgs = idridCfg.segmentation_test_images;
    segTrainMasks = idridCfg.segmentation_train_masks;
    segTestMasks = idridCfg.segmentation_test_masks;

    if exist(segTrainImgs, 'dir') == 7
        trImgs = dir(fullfile(segTrainImgs, '*.jpg'));
        statusReport.segmentation.train_images = numel(trImgs);
    end
    if exist(segTestImgs, 'dir') == 7
        tsImgs = dir(fullfile(segTestImgs, '*.jpg'));
        statusReport.segmentation.test_images = numel(tsImgs);
    end

    lesionTypes = {'Microaneurysms', 'Haemorrhages', 'Hard Exudates', 'Soft Exudates', 'Optic Disc'};
    totalMasksFound = 0;

    for lt = 1:numel(lesionTypes)
        lName = lesionTypes{lt};
        % Check train masks
        cntTrain = 0;
        if exist(segTrainMasks, 'dir') == 7
            subDirs = dir(segTrainMasks);
            for d = 1:numel(subDirs)
                if subDirs(d).isdir && contains(lower(subDirs(d).name), lower(lName(1:min(4, length(lName)))))
                    mFiles = dir(fullfile(segTrainMasks, subDirs(d).name, '*.tif'));
                    cntTrain = cntTrain + numel(mFiles);
                end
            end
        end

        % Check test masks
        cntTest = 0;
        if exist(segTestMasks, 'dir') == 7
            subDirs = dir(segTestMasks);
            for d = 1:numel(subDirs)
                if subDirs(d).isdir && contains(lower(subDirs(d).name), lower(lName(1:min(4, length(lName)))))
                    mFiles = dir(fullfile(segTestMasks, subDirs(d).name, '*.tif'));
                    cntTest = cntTest + numel(mFiles);
                end
            end
        end

        cleanFld = strrep(lower(lName), ' ', '_');
        statusReport.segmentation.masks_detected.(cleanFld) = cntTrain + cntTest;
        totalMasksFound = totalMasksFound + cntTrain + cntTest;
    end

    if (statusReport.segmentation.train_images + statusReport.segmentation.test_images) > 0 && totalMasksFound > 0
        statusReport.has_segmentation = true;
        statusReport.num_lesion_masks_found = totalMasksFound;
    end

    % =========================================================================
    % 3. LOCALIZATION AUDIT
    % =========================================================================
    if exist(idridCfg.localization_od_train, 'file') == 2
        try
            t = readtable(idridCfg.localization_od_train);
            statusReport.localization.od_train_rows = height(t);
        catch
        end
    end
    if exist(idridCfg.localization_od_test, 'file') == 2
        try
            t = readtable(idridCfg.localization_od_test);
            statusReport.localization.od_test_rows = height(t);
        catch
        end
    end
    if exist(idridCfg.localization_fovea_train, 'file') == 2
        try
            t = readtable(idridCfg.localization_fovea_train);
            statusReport.localization.fovea_train_rows = height(t);
        catch
        end
    end
    if exist(idridCfg.localization_fovea_test, 'file') == 2
        try
            t = readtable(idridCfg.localization_fovea_test);
            statusReport.localization.fovea_test_rows = height(t);
        catch
        end
    end

    if (statusReport.localization.od_train_rows + statusReport.localization.fovea_train_rows) > 0
        statusReport.has_localization = true;
    end

    statusReport.is_available = (statusReport.has_disease_grading && statusReport.has_segmentation);
    statusReport.message = sprintf('IDRiD verified: Grading (%d images), Segmentation (%d images, %d masks), Localization (%d OD, %d Fovea).', ...
        totalGradingMatched, ...
        statusReport.segmentation.train_images + statusReport.segmentation.test_images, ...
        totalMasksFound, ...
        statusReport.localization.od_train_rows + statusReport.localization.od_test_rows, ...
        statusReport.localization.fovea_train_rows + statusReport.localization.fovea_test_rows);
end
