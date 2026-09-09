function spec = calculate_specificity(y_true, y_pred, positiveClass)
% CALCULATE_SPECIFICITY Computes Specificity: TN / (TN + FP)
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Critical Metric:
%   Minimizes unnecessary tertiary referrals and burden on overburdened eye hospitals.
%
% Usage:
%   spec = calculate_specificity(trueLabels, predictedLabels, 1);

    if nargin < 3
        positiveClass = 1;
    end

    TN = sum((y_true ~= positiveClass) & (y_pred ~= positiveClass));
    FP = sum((y_true ~= positiveClass) & (y_pred == positiveClass));

    if (TN + FP) > 0
        spec = TN / (TN + FP);
    else
        spec = NaN;
    end
end
