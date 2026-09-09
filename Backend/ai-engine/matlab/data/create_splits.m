function [splitTable, splitSummary] = create_splits(datasetTable, trainRatio, valRatio, testRatio, randomSeed, outputDir)
% CREATE_SPLITS Generates reproducible train/validation/test partitions
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Features:
%   - Stratified sampling across 5 DR severity grades to preserve class distribution
%   - Reproducible partitioning via fixed random seed (default: 42)
%   - Preserves independent identity of external datasets (e.g., Messidor-2 remains test)
%   - Exports partition tables to data/splits/ if outputDir is provided
%
% Usage:
%   [splitTable, summary] = create_splits(datasetTable);
%   [splitTable, summary] = create_splits(datasetTable, 0.70, 0.15, 0.15, 42, 'data/splits/aptos');

    if nargin < 2 || isempty(trainRatio), trainRatio = 0.70; end
    if nargin < 3 || isempty(valRatio),   valRatio = 0.15;   end
    if nargin < 4 || isempty(testRatio),  testRatio = 0.15;  end
    if nargin < 5 || isempty(randomSeed), randomSeed = 42;   end
    if nargin < 6, outputDir = ''; end

    splitSummary = struct();
    splitSummary.total_images = 0;
    splitSummary.train_count = 0;
    splitSummary.val_count = 0;
    splitSummary.test_count = 0;
    splitSummary.stratified = false;

    if nargin < 1 || isempty(datasetTable) || height(datasetTable) == 0
        fprintf('[INFO] No dataset records provided to create_splits. Splitting requires local data.\n');
        splitTable = create_standard_table();
        return;
    end

    % Normalize ratios
    totalRatio = trainRatio + valRatio + testRatio;
    trainRatio = trainRatio / totalRatio;
    valRatio = valRatio / totalRatio;
    testRatio = testRatio / totalRatio;

    rng(randomSeed);
    splitTable = datasetTable;
    n = height(splitTable);
    splitSummary.total_images = n;

    assignedSplits = repmat("unassigned", n, 1);

    % Handle external evaluation datasets (Messidor-2)
    isExternal = (splitTable.dataset == "messidor2");
    if any(isExternal)
        assignedSplits(isExternal) = "test";
    end

    % Stratified split for labeled classification samples
    isClassification = (splitTable.has_dr_label & ~isExternal & ~isnan(splitTable.dr_grade));
    grades = splitTable.dr_grade;

    if any(isClassification)
        uniqueGrades = unique(grades(isClassification));
        splitSummary.stratified = true;

        for g = 1:numel(uniqueGrades)
            ug = uniqueGrades(g);
            gradeIdx = find(isClassification & (grades == ug));
            numInGrade = numel(gradeIdx);

            perm = gradeIdx(randperm(numInGrade));
            nTrain = round(numInGrade * trainRatio);
            nVal = round(numInGrade * valRatio);

            assignedSplits(perm(1:nTrain)) = "train";
            if nTrain + nVal <= numInGrade
                assignedSplits(perm(nTrain+1 : nTrain+nVal)) = "val";
                assignedSplits(perm(nTrain+nVal+1 : end)) = "test";
            else
                assignedSplits(perm(nTrain+1 : end)) = "val";
            end
        end
    end

    % Random split for unlabelled / vessel segmentation samples (e.g. DRIVE)
    isRemaining = (assignedSplits == "unassigned");
    if any(isRemaining)
        remIdx = find(isRemaining);
        numRem = numel(remIdx);
        perm = remIdx(randperm(numRem));

        nTrain = round(numRem * trainRatio);
        nVal = round(numRem * valRatio);

        assignedSplits(perm(1:nTrain)) = "train";
        if nTrain + nVal <= numRem
            assignedSplits(perm(nTrain+1 : nTrain+nVal)) = "val";
            assignedSplits(perm(nTrain+nVal+1 : end)) = "test";
        else
            assignedSplits(perm(nTrain+1 : end)) = "val";
        end
    end

    splitTable.split = assignedSplits;

    splitSummary.train_count = sum(splitTable.split == "train");
    splitSummary.val_count = sum(splitTable.split == "val");
    splitSummary.test_count = sum(splitTable.split == "test");

    % Export split files if output directory specified
    if ~isempty(outputDir)
        if exist(outputDir, 'dir') ~= 7
            mkdir(outputDir);
        end
        writetable(splitTable(splitTable.split == "train", :), fullfile(outputDir, 'train.csv'));
        writetable(splitTable(splitTable.split == "val", :), fullfile(outputDir, 'val.csv'));
        writetable(splitTable(splitTable.split == "test", :), fullfile(outputDir, 'test.csv'));
        writetable(splitTable, fullfile(outputDir, 'all_splits.csv'));
        fprintf('[Retino-AI] Exported split tables to %s\n', outputDir);
    end

    fprintf('[Retino-AI] Split summary: %d Train (%.1f%%), %d Val (%.1f%%), %d Test (%.1f%%)\n', ...
        splitSummary.train_count, (splitSummary.train_count/n)*100, ...
        splitSummary.val_count, (splitSummary.val_count/n)*100, ...
        splitSummary.test_count, (splitSummary.test_count/n)*100);
end
