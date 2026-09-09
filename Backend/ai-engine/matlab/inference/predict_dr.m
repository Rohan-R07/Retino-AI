function [result, predictedGrade, classProbabilities, confidence] = predict_dr(imageInput, modelInput)
% PREDICT_DR Unified DR severity classification inference for unannotated retinal fundus images
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Architecture Flow:
%   Raw Retinal Image (NO annotations or masks required)
%          ↓
%   Quality Assessment Gatekeeper (focus, illumination, retinal FOV)
%          ↓ (if UNGRADABLE -> halts cleanly with advisory)
%   Preprocessing (FOV crop, standardized resize, green channel, CLAHE)
%          ↓
%   12 Mask-Free Feature Extraction (Color statistics + GLCM Texture)
%          ↓
%   Random Forest Classifier Inference
%          ↓
%   Predicted DR Grade (0-4), Class Probabilities, Confidence, Referral Status
%
% Features (12 Mask-Free, Image-Directly-Computable):
%   1. mean_red        2. mean_green      3. mean_blue
%   4. std_red         5. std_green       6. std_blue
%   7. green_mean      8. green_contrast
%   9. glcm_contrast  10. glcm_correlation 11. glcm_energy 12. glcm_homogeneity
%
% Usage:
%   result = predict_dr('sample_fundus.png');
%   result = predict_dr(imgMatrix);
%   result = predict_dr(imageInput, 'models/saved/dr_random_forest.mat');
%
% Outputs:
%   result - Struct with fields:
%       .predicted_grade      - Integer in {0, 1, 2, 3, 4} (or NaN if ungradable)
%       .class_probabilities  - 1x5 double array summing to ~1.0
%       .confidence           - Double in [0.0, 1.0] (max class probability)
%       .quality              - Full quality assessment struct
%       .status               - 'GRADABLE' or 'UNGRADABLE'
%       .feature_vector       - 1x12 double array of extracted features
%       .feature_names        - 1x12 cell array of feature names in exact order
%       .referral_recommended - Logical (true when grade >= 2)
%       .advisory             - Text explanation if ungradable

    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(fileparts(thisDir));
    matlabDir = fullfile(rootDir, 'matlab');

    if exist(fullfile(matlabDir, 'setup_paths.m'), 'file') == 2
        run(fullfile(matlabDir, 'setup_paths.m'));
    else
        addpath(genpath(matlabDir));
        addpath(fullfile(rootDir, 'config'));
    end

    featureNames = { ...
        'mean_red', 'mean_green', 'mean_blue', ...
        'std_red', 'std_green', 'std_blue', ...
        'green_mean', 'green_contrast', ...
        'glcm_contrast', 'glcm_correlation', ...
        'glcm_energy', 'glcm_homogeneity' ...
    };

    % 1. Load Trained Model
    model = [];
    if nargin >= 2 && ~isempty(modelInput)
        if isstruct(modelInput)
            model = modelInput;
        elseif ischar(modelInput) || isstring(modelInput)
            if exist(modelInput, 'file') == 2
                matData = load(modelInput);
                if isfield(matData, 'model'), model = matData.model; else, model = matData; end
            end
        end
    end

    if isempty(model)
        candidatePaths = { ...
            fullfile(rootDir, 'models', 'saved', 'dr_random_forest.mat'), ...
            fullfile(rootDir, 'matlab', 'models', 'saved', 'dr_random_forest.mat'), ...
            fullfile(pwd, 'models', 'saved', 'dr_random_forest.mat'), ...
            fullfile(pwd, 'matlab', 'models', 'saved', 'dr_random_forest.mat') ...
        };
        for k = 1:numel(candidatePaths)
            if exist(candidatePaths{k}, 'file') == 2
                matData = load(candidatePaths{k});
                if isfield(matData, 'model'), model = matData.model; else, model = matData; end
                break;
            end
        end
    end

    result = struct();
    result.status = 'INITIALIZED';
    result.is_gradable = false;
    result.predicted_grade = NaN;
    result.class_probabilities = zeros(1, 5);
    result.confidence = 0.0;
    result.quality = struct();
    result.feature_vector = [];
    result.feature_names = featureNames;
    result.referral_recommended = false;
    result.advisory = '';

    % 2. Quality Assessment Gatekeeper
    try
        quality = assess_image_quality(imageInput);
    catch ME
        quality = struct('is_gradable', false, 'advisory_message', ME.message);
    end
    result.quality = quality;

    if ~quality.is_gradable
        result.status = 'UNGRADABLE';
        result.is_gradable = false;
        result.advisory = quality.advisory_message;
        predictedGrade = NaN;
        classProbabilities = zeros(1, 5);
        confidence = 0.0;
        return;
    end

    result.is_gradable = true;

    % 3. Preprocessing
    try
        prep = preprocess_fundus(imageInput);
    catch ME
        result.status = 'PREPROCESSING_FAILED';
        result.advisory = sprintf('Preprocessing failed: %s', ME.message);
        predictedGrade = NaN;
        classProbabilities = zeros(1, 5);
        confidence = 0.0;
        return;
    end

    % 4. 12 Mask-Free Feature Extraction
    try
        feats = extract_features(prep);
        featVector = feats.vector(1:12);
        featNames = feats.names(1:12);
    catch ME
        result.status = 'FEATURE_EXTRACTION_FAILED';
        result.advisory = sprintf('Feature extraction failed: %s', ME.message);
        predictedGrade = NaN;
        classProbabilities = zeros(1, 5);
        confidence = 0.0;
        return;
    end

    result.feature_vector = featVector;
    result.feature_names = featNames;

    % 5. Model Inference
    if isempty(model)
        result.status = 'MODEL_NOT_FOUND';
        result.advisory = 'Trained dr_random_forest.mat could not be located.';
        predictedGrade = NaN;
        classProbabilities = zeros(1, 5);
        confidence = 0.0;
        return;
    end

    predGrade = NaN;
    probs = zeros(1, 5);

    % Case A: Native MATLAB TreeBagger object
    if isfield(model, 'classifier') && (isa(model.classifier, 'TreeBagger') || ismethod(model.classifier, 'predict'))
        [predCell, scores] = predict(model.classifier, featVector);
        predGrade = str2double(predCell{1});
        probs = double(scores(1, :));
    elseif isa(model, 'TreeBagger')
        [predCell, scores] = predict(model, featVector);
        predGrade = str2double(predCell{1});
        probs = double(scores(1, :));
    % Case B: Native Decision Tree Ensemble Struct
    elseif isfield(model, 'trees')
        nTrees = numel(model.trees);
        treeProbs = zeros(1, 5);
        for t = 1:nTrees
            if iscell(model.trees)
                tr = model.trees{t};
            else
                tr = model.trees(t);
            end
            node = 1;
            cLeft = tr.children_left;
            cRight = tr.children_right;
            featIdxs = tr.feature;
            threshs = tr.threshold;
            vals = tr.value;

            while node <= numel(featIdxs) && cLeft(node) >= 0
                f = featIdxs(node) + 1; % 1-based indexing
                th = threshs(node);
                if featVector(f) <= th
                    node = cLeft(node) + 1;
                else
                    node = cRight(node) + 1;
                end
            end
            nodeVal = double(vals(node, :));
            sVal = sum(nodeVal);
            if sVal > 0
                treeProbs = treeProbs + (nodeVal / sVal);
            else
                treeProbs = treeProbs + 0.2;
            end
        end
        probs = treeProbs / nTrees;
        [~, maxIdx] = max(probs);
        if isfield(model, 'classes')
            classes = double(model.classes);
            predGrade = classes(maxIdx);
        else
            predGrade = maxIdx - 1;
        end
    else
        % Fallback rule-based or unhandled
        result.status = 'UNSUPPORTED_MODEL_STRUCTURE';
        predictedGrade = NaN;
        classProbabilities = zeros(1, 5);
        confidence = 0.0;
        return;
    end

    % Normalize probabilities to sum to 1.0
    pSum = sum(probs);
    if pSum > 0
        probs = probs / pSum;
    else
        probs = ones(1, 5) / 5;
    end
    conf = max(probs);

    % Populate output struct
    result.predicted_grade = round(predGrade);
    result.class_probabilities = probs;
    result.confidence = conf;
    result.referral_recommended = (result.predicted_grade >= 2);
    result.status = 'GRADABLE';
    result.advisory = sprintf('DR Grade %d predicted with %.1f%% confidence.', ...
        result.predicted_grade, conf * 100);

    predictedGrade = result.predicted_grade;
    classProbabilities = result.class_probabilities;
    confidence = result.confidence;
end
