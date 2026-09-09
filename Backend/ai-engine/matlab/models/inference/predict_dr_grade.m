function [predictedGrade, confidence, classProbabilities] = predict_dr_grade(model, featureVector)
% PREDICT_DR_GRADE Interface for DR severity grade inference using trained model
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Outputs:
%   predictedGrade     - Integer grade (0 to 4)
%   confidence         - Confidence score [0.0 to 1.0]
%   classProbabilities - 1x5 probability distribution across ICDR grades
%
% Note: Inference logic executes with trained model in Phase 8.

    isTrained = (isfield(model, 'is_trained') && model.is_trained) || ...
                (isfield(model, 'trained') && model.trained);
    if isempty(model) || ~isTrained
        predictedGrade = NaN;
        confidence = 0.0;
        classProbabilities = zeros(1, 5);
        return;
    end

    if isfield(model, 'classifier') && (isa(model.classifier, 'TreeBagger') || ismethod(model.classifier, 'predict'))
        [labelCell, scores] = predict(model.classifier, featureVector);
        predictedGrade = str2double(labelCell{1});
        classProbabilities = double(scores(1, :));
        confidence = max(classProbabilities);
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
                f = featIdxs(node) + 1;
                th = threshs(node);
                if featureVector(f) <= th
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
        classProbabilities = treeProbs / nTrees;
        [confidence, maxIdx] = max(classProbabilities);
        if isfield(model, 'classes')
            classes = double(model.classes);
            predictedGrade = classes(maxIdx);
        else
            predictedGrade = maxIdx - 1;
        end
    else
        error('RetinoAI:UnsupportedModel', 'Unsupported or uninitialized model format.');
    end
end
