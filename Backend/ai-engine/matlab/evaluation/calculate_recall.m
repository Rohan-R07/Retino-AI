function rec = calculate_recall(y_true, y_pred, positiveClass)
% CALCULATE_RECALL Computes Recall (equivalent to Sensitivity)
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India

    if nargin < 3
        positiveClass = 1;
    end

    rec = calculate_sensitivity(y_true, y_pred, positiveClass);
end
