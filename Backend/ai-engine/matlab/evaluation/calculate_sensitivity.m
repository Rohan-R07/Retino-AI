function sens = calculate_sensitivity(y_true, y_pred, positiveClass)
% CALCULATE_SENSITIVITY Computes Sensitivity / Recall: TP / (TP + FN)
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Critical Metric:
%   In medical screening for preventable blindness, high sensitivity is vital
%   to minimize false negatives (missed cases of sight-threatening retinopathy).
%
% Usage:
%   sens = calculate_sensitivity(trueLabels, predictedLabels, 1);

    if nargin < 3
        positiveClass = 1;
    end

    TP = sum((y_true == positiveClass) & (y_pred == positiveClass));
    FN = sum((y_true == positiveClass) & (y_pred ~= positiveClass));

    if (TP + FN) > 0
        sens = TP / (TP + FN);
    else
        sens = NaN;
    end
end
