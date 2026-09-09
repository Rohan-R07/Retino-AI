function [trainedModel, evalReport] = train_dr_model(customConfig)
% TRAIN_DR_MODEL Trains Random Forest DR classifier using full available APTOS dataset
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Datasets:
%   - APTOS 2019: Primary DR grading training data across all available training images
%   - IDRiD Disease Grading: Supplementary DR grading data
%   - DRIVE: Vessel validation only (NOT used for DR grade training)
%   - Messidor-2: Skipped (unavailable)
%
% 12 Mask-Free Features (computable directly from image):
%   1. mean_red        2. mean_green      3. mean_blue
%   4. std_red         5. std_green       6. std_blue
%   7. green_mean      8. green_contrast
%   9. glcm_contrast  10. glcm_correlation 11. glcm_energy 12. glcm_homogeneity
%
% Clinical Target:
%   - 5-Class DR Severity (0=No DR, 1=Mild, 2=Moderate, 3=Severe, 4=Proliferative)
%   - Referable DR Threshold: Grade >= 2
%
% Output:
%   trainedModel - Struct with classifier, metadata, feature names, classes
%   evalReport   - Metrics on stratified held-out test set (acc, confusion mat, sens, spec)

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(fileparts(thisDir)));
    matlabDir = fullfile(rootDir, 'matlab');

    if exist(fullfile(matlabDir, 'setup_paths.m'), 'file') == 2
        run(fullfile(matlabDir, 'setup_paths.m'));
    else
        addpath(genpath(matlabDir));
        addpath(fullfile(rootDir, 'config'));
    end

    fprintf('=================================================================\n');
    fprintf('  RETINO-AI: RANDOM FOREST DR CLASSIFIER TRAINING PIPELINE       \n');
    fprintf('  Dataset: Full Available APTOS 2019 (+ IDRiD Supplementary)     \n');
    fprintf('  Target: 5-Class ICDR DR Severity (0-4)                         \n');
    fprintf('=================================================================\n\n');

    % 1. Config and Parameters
    if nargin < 1 || isempty(customConfig)
        try
            cfg = training_config();
        catch
            cfg = struct();
            cfg.random_seed = 42;
            cfg.model.rf.num_trees = 100;
            cfg.model.rf.min_leaf_size = 5;
        end
    else
        cfg = customConfig;
    end

    rng(42); % Fixed seed for deterministic reproducibility

    featureNames = { ...
        'mean_red', 'mean_green', 'mean_blue', ...
        'std_red', 'std_green', 'std_blue', ...
        'green_mean', 'green_contrast', ...
        'glcm_contrast', 'glcm_correlation', ...
        'glcm_energy', 'glcm_homogeneity' ...
    };
    classLabels = { ...
        '0 - No DR', ...
        '1 - Mild NPDR', ...
        '2 - Moderate NPDR', ...
        '3 - Severe NPDR', ...
        '4 - Proliferative DR' ...
    };
    numClasses = 5;

    % 2. Locate Datasets
    aptosCsv = fullfile(rootDir, 'data', 'raw', 'aptos', 'train.csv');
    aptosImgDir = fullfile(rootDir, 'data', 'raw', 'aptos', 'train_images');
    idridCsv = fullfile(rootDir, 'data', 'raw', 'idrid', 'Disease Grading', ...
                        '2. Groundtruths', 'a. IDRiD_Disease Grading_Training Labels.csv');
    idridImgDir = fullfile(rootDir, 'data', 'raw', 'idrid', 'Disease Grading', ...
                          '1. Original Images', 'a. Training Set');

    samplePaths = {};
    sampleLabels = [];
    sampleDatasets = {};

    % Load Full APTOS Dataset
    if exist(aptosCsv, 'file') == 2 && exist(aptosImgDir, 'dir') == 7
        fprintf('[DATA] Reading full APTOS 2019 dataset...\n');
        tAptos = readtable(aptosCsv);
        for k = 1:height(tAptos)
            p = fullfile(aptosImgDir, [tAptos.id_code{k}, '.png']);
            if exist(p, 'file') == 2
                samplePaths{end+1} = p; %#ok<AGROW>
                sampleLabels(end+1) = tAptos.diagnosis(k); %#ok<AGROW>
                sampleDatasets{end+1} = 'APTOS'; %#ok<AGROW>
            end
        end
        fprintf('  -> APTOS images loaded: %d across all grades.\n', sum(strcmp(sampleDatasets, 'APTOS')));
    end

    % Load Supplementary IDRiD Dataset
    if exist(idridCsv, 'file') == 2 && exist(idridImgDir, 'dir') == 7
        fprintf('[DATA] Reading IDRiD Disease Grading dataset...\n');
        tIdrid = readtable(idridCsv);
        colName = tIdrid.Properties.VariableNames{2};
        imgCol = tIdrid.Properties.VariableNames{1};
        for k = 1:height(tIdrid)
            name = tIdrid.(imgCol){k};
            p = fullfile(idridImgDir, [name, '.jpg']);
            if exist(p, 'file') == 2
                samplePaths{end+1} = p; %#ok<AGROW>
                sampleLabels(end+1) = tIdrid.(colName)(k); %#ok<AGROW>
                sampleDatasets{end+1} = 'IDRiD'; %#ok<AGROW>
            end
        end
        fprintf('  -> IDRiD images loaded: %d across all grades.\n', sum(strcmp(sampleDatasets, 'IDRiD')));
    end

    totalSamples = numel(samplePaths);
    fprintf('\n[PIPELINE] Total training pool: %d images.\n', totalSamples);
    if totalSamples < 10
        error('RetinoAI:InsufficientData', 'Not enough images found to train model.');
    end

    % 3. Extract 12 Mask-Free Features
    fprintf('[PIPELINE] Extracting 12 mask-free features for all dataset images...\n');
    X = zeros(totalSamples, 12);
    y = sampleLabels(:);
    validMask = true(totalSamples, 1);

    for i = 1:totalSamples
        imgPath = samplePaths{i};
        try
            prep = preprocess_fundus(imgPath);
            feats = extract_features(prep);
            X(i, :) = feats.vector(1:12);
        catch ME
            validMask(i) = false;
        end
        if mod(i, 200) == 0 || i == totalSamples
            fprintf('  Processed %d / %d images\n', i, totalSamples);
        end
    end

    X = X(validMask, :);
    y = y(validMask);
    totalValid = size(X, 1);
    fprintf('[PIPELINE] Successfully extracted features: %d / %d images.\n', totalValid, totalSamples);

    % 4. Stratified Train / Test Split (80% Train, 20% Held-Out Test)
    fprintf('[SPLIT] Creating stratified train (80%%) and test (20%%) partitions...\n');
    trainIdx = [];
    testIdx = [];
    for g = 0:4
        cIdx = find(y == g);
        nClass = numel(cIdx);
        nTrain = max(1, round(0.80 * nClass));
        % Random permutation with deterministic seed
        perm = randperm(nClass);
        trainIdx = [trainIdx; cIdx(perm(1:nTrain))]; %#ok<AGROW>
        testIdx = [testIdx; cIdx(perm(nTrain+1:end))]; %#ok<AGROW>
    end

    X_train = X(trainIdx, :);
    y_train = y(trainIdx);
    X_test = X(testIdx, :);
    y_test = y(testIdx);

    fprintf('  -> Train pool: %d images | Held-out test pool: %d images\n', ...
        numel(y_train), numel(y_test));

    % 5. Train Random Forest (100 Trees)
    numTrees = 100;
    if isfield(cfg, 'model') && isfield(cfg.model, 'rf') && isfield(cfg.model.rf, 'num_trees')
        numTrees = cfg.model.rf.num_trees;
    end

    fprintf('[TRAIN] Training Random Forest (%d trees, 12 features, 5 classes)...\n', numTrees);
    try
        rfClassifier = TreeBagger(numTrees, X_train, y_train, ...
            'Method', 'classification', ...
            'MinLeafSize', 5, ...
            'PredictorNames', featureNames);
        useTreeBagger = true;
    catch
        rfClassifier = fitcensemble(X_train, y_train, 'Method', 'Bag', ...
            'NumLearningCycles', numTrees, 'PredictorNames', featureNames);
        useTreeBagger = false;
    end

    % 6. Evaluate on Held-Out Test Set
    fprintf('[EVAL] Evaluating model on held-out test split...\n');
    if useTreeBagger
        [predLabels, ~] = predict(rfClassifier, X_test);
        y_pred = cellfun(@str2double, predLabels);
    else
        y_pred = predict(rfClassifier, X_test);
    end

    acc = mean(y_pred == y_test);

    % 5x5 Confusion Matrix
    confMat = zeros(5, 5);
    for i = 1:numel(y_test)
        actual = y_test(i) + 1;
        pred = y_pred(i) + 1;
        if actual >= 1 && actual <= 5 && pred >= 1 && pred <= 5
            confMat(actual, pred) = confMat(actual, pred) + 1;
        end
    end

    % Referable DR Metrics (Threshold: Grade >= 2)
    refActual = (y_test >= 2);
    refPred = (y_pred >= 2);

    tp = sum(refActual & refPred);
    fn = sum(refActual & ~refPred);
    tn = sum(~refActual & ~refPred);
    fp = sum(~refActual & refPred);

    sens = tp / (tp + fn);
    spec = tn / (tn + fp);
    refAcc = (tp + tn) / (tp + tn + fp + fn);

    fprintf('\n=================================================================\n');
    fprintf('  RETRAINED RANDOM FOREST EVALUATION (HELD-OUT TEST SET)         \n');
    fprintf('=================================================================\n');
    fprintf('  Total Test Samples: %d\n', numel(y_test));
    fprintf('  5-Class DR Accuracy: %.2f%%\n', acc * 100);
    fprintf('  Referable DR Accuracy (Grade >= 2): %.2f%%\n', refAcc * 100);
    fprintf('  Referable DR Sensitivity: %.2f%% (%d / %d)\n', sens * 100, tp, tp + fn);
    fprintf('  Referable DR Specificity: %.2f%% (%d / %d)\n', spec * 100, tn, tn + fp);
    fprintf('\n  5-Class Confusion Matrix (Rows: Actual 0-4, Cols: Predicted 0-4):\n');
    disp(confMat);

    % 7. Package and Save
    trainedModel = struct();
    trainedModel.type = 'random_forest';
    trainedModel.classifier = rfClassifier;
    trainedModel.feature_names = featureNames;
    trainedModel.num_features = 12;
    trainedModel.classes = [0, 1, 2, 3, 4];
    trainedModel.class_labels = classLabels;
    trainedModel.num_classes = numClasses;
    trainedModel.is_trained = true;
    trainedModel.training_samples = numel(y_train);
    trainedModel.test_samples = numel(y_test);
    trainedModel.accuracy = acc;
    trainedModel.referral_accuracy = refAcc;
    trainedModel.referral_sensitivity = sens;
    trainedModel.referral_specificity = spec;
    trainedModel.confusion_matrix = confMat;
    trainedModel.training_timestamp = datestr(now);

    evalReport = struct();
    evalReport.accuracy = acc;
    evalReport.referral_accuracy = refAcc;
    evalReport.referral_sensitivity = sens;
    evalReport.referral_specificity = spec;
    evalReport.confusion_matrix = confMat;
    evalReport.num_train = numel(y_train);
    evalReport.num_test = numel(y_test);
    evalReport.feature_names = featureNames;

    outDirs = {
        fullfile(rootDir, 'models', 'saved'), ...
        fullfile(rootDir, 'matlab', 'models', 'saved')
    };

    for d = 1:numel(outDirs)
        destDir = outDirs{d};
        if ~exist(destDir, 'dir'), mkdir(destDir); end
        matFile = fullfile(destDir, 'dr_random_forest.mat');
        model = trainedModel; %#ok<NASGU>
        metadata = evalReport; %#ok<NASGU>
        save(matFile, 'model', 'metadata');
        fprintf('[SAVED] Model artifact saved -> %s\n', matFile);
    end

    metaJsonFile = fullfile(rootDir, 'models', 'saved', 'dr_model_metadata.json');
    try
        jsonStr = jsonencode(evalReport, 'PrettyPrint', true);
        fid = fopen(metaJsonFile, 'w');
        if fid ~= -1
            fwrite(fid, jsonStr, 'char');
            fclose(fid);
        end
    catch
    end
end
