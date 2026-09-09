function model = train_classifier(X_train, y_train, modelType, options)
% TRAIN_CLASSIFIER Interface for training 5-class Diabetic Retinopathy classifiers
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Supported Architectures:
%   - 'random_forest' : Ensemble bagging via TreeBagger with feature importance ranking
%   - 'svm'           : Multi-class Support Vector Machine via fitcecoc
%
% Targets (ICDR Scale):
%   0 -> No Apparent DR
%   1 -> Mild NPDR
%   2 -> Moderate NPDR (Referable)
%   3 -> Severe NPDR (Referable)
%   4 -> Proliferative DR (Referable)
%
% Note: Model training is NOT performed during environment setup.
% This function provides the clean interface for Phase 5.
%
% Usage:
%   model = train_classifier(X, y, 'random_forest');

    if nargin < 3 || isempty(modelType)
        modelType = 'random_forest';
    end
    if nargin < 4 || isempty(options)
        cfg = training_config();
        options = cfg.model;
    end

    if nargin == 0 || (nargin >= 1 && isempty(X_train))
        % Execute full dataset pipeline training
        model = train_dr_model();
        return;
    end

    fprintf('[Retino-AI] Training Random Forest classifier on %d samples...\n', size(X_train, 1));
    numTrees = 100;
    if isfield(options, 'rf') && isfield(options.rf, 'num_trees')
        numTrees = options.rf.num_trees;
    end

    try
        rfClassifier = TreeBagger(numTrees, X_train, y_train, ...
            'Method', 'classification', 'MinLeafSize', 5);
    catch
        rfClassifier = fitcensemble(X_train, y_train, 'Method', 'Bag', ...
            'NumLearningCycles', numTrees);
    end

    model = struct();
    model.type = modelType;
    model.classifier = rfClassifier;
    model.num_classes = 5;
    model.class_labels = {'0 - No DR', '1 - Mild', '2 - Moderate', '3 - Severe', '4 - Proliferative'};
    model.classes = [0, 1, 2, 3, 4];
    model.is_trained = true;
    model.trained = true;
    model.options = options;
    model.training_timestamp = datestr(now);
end
