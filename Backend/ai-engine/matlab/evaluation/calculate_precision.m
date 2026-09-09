function prec = calculate_precision(y_true, y_pred, positiveClass)
% CALCULATE_PRECISION Computes Positive Predictive Value: TP / (TP + FP)
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Usage:
%   prec = calculate_precision(trueLabels, predictedLabels, 1);

    if nargin < 3
        positiveClass = 1;
    end

    TP = sum((y_true == positiveClass) & (y_pred == positiveClass));
    FP = sum((y_true ~= positiveClass) & (y_pred == positiveClass));

    if (TP + FP) > 0
        prec = TP / (TP + FP);
    else
        prec = NaN;
    end
end
