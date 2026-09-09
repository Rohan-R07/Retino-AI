function metrics = evaluate_classification(y_true, y_pred, numClasses)
% EVALUATE_CLASSIFICATION Comprehensive clinical evaluation of DR predictions
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Computes:
%   - Multi-Class Overall Accuracy & Macro F1
%   - Per-Class Sensitivity, Specificity, Precision, F1 (Grades 0 to 4)
%   - Quadratic Weighted Kappa (QWK) for ordinal severity agreement
%   - Binary Referable DR Metrics (Grades 0-1 vs Grades 2-4)
%
% Output:
%   metrics - Struct containing all computed statistical performance measures

    if nargin < 3 || isempty(numClasses)
        numClasses = 5;
    end

    metrics = struct();
    y_true = double(y_true(:));
    y_pred = double(y_pred(:));
    N = numel(y_true);

    if N == 0
        fprintf('[WARN] Empty predictions passed to evaluate_classification.\n');
        return;
    end

    % 1. Overall Accuracy
    metrics.accuracy = sum(y_true == y_pred) / N;

    % 2. Per-class metrics
    classMetrics = struct();
    f1List = [];
    sensList = [];
    specList = [];

    for c = 0:(numClasses - 1)
        sens = calculate_sensitivity(y_true, y_pred, c);
        spec = calculate_specificity(y_true, y_pred, c);
        prec = calculate_precision(y_true, y_pred, c);
        f1 = calculate_f1(y_true, y_pred, c);

        fld = sprintf('grade_%d', c);
        classMetrics.(fld).sensitivity = sens;
        classMetrics.(fld).specificity = spec;
        classMetrics.(fld).precision = prec;
        classMetrics.(fld).f1_score = f1;

        if ~isnan(f1),   f1List(end+1) = f1; end %#ok<AGROW>
        if ~isnan(sens), sensList(end+1) = sens; end %#ok<AGROW>
        if ~isnan(spec), specList(end+1) = spec; end %#ok<AGROW>
    end

    metrics.per_class = classMetrics;
    metrics.macro_f1 = mean(f1List);
    metrics.macro_sensitivity = mean(sensList);
    metrics.macro_specificity = mean(specList);

    % 3. Quadratic Weighted Kappa (QWK)
    metrics.quadratic_weighted_kappa = compute_qwk(y_true, y_pred, numClasses);

    % 4. Binary Referable DR Evaluation (Grade >= 2)
    bin_true = (y_true >= 2);
    bin_pred = (y_pred >= 2);

    metrics.referable_dr.sensitivity = calculate_sensitivity(bin_true, bin_pred, 1);
    metrics.referable_dr.specificity = calculate_specificity(bin_true, bin_pred, 1);
    metrics.referable_dr.precision = calculate_precision(bin_true, bin_pred, 1);
    metrics.referable_dr.f1_score = calculate_f1(bin_true, bin_pred, 1);
    metrics.referable_dr.accuracy = sum(bin_true == bin_pred) / N;
end

function k = compute_qwk(actual, pred, numClasses)
    C = zeros(numClasses, numClasses);
    for i = 1:numel(actual)
        a = actual(i) + 1;
        p = pred(i) + 1;
        if a >= 1 && a <= numClasses && p >= 1 && p <= numClasses
            C(a, p) = C(a, p) + 1;
        end
    end
    N = sum(C(:));
    if N == 0, k = NaN; return; end

    % Weight matrix
    W = zeros(numClasses, numClasses);
    for i = 1:numClasses
        for j = 1:numClasses
            W(i, j) = ((i - j)^2) / ((numClasses - 1)^2);
        end
    end

    % Expected matrix
    histActual = sum(C, 2);
    histPred = sum(C, 1);
    E = (histActual * histPred) / N;

    num = sum(sum(W .* C));
    den = sum(sum(W .* E));

    if den == 0
        k = 1.0;
    else
        k = 1.0 - (num / den);
    end
end
