function f1 = calculate_f1(y_true, y_pred, positiveClass)
% CALCULATE_F1 Computes Harmonic Mean of Precision and Recall
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Formula:
%   F1 = 2 * (Precision * Recall) / (Precision + Recall)

    if nargin < 3
        positiveClass = 1;
    end

    prec = calculate_precision(y_true, y_pred, positiveClass);
    rec = calculate_recall(y_true, y_pred, positiveClass);

    if isnan(prec) || isnan(rec) || (prec + rec) == 0
        f1 = 0;
    else
        f1 = 2 * (prec * rec) / (prec + rec);
    end
end
