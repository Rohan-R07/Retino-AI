function fig = plot_confusion_matrix(y_true, y_pred, classLabels, savePath)
% PLOT_CONFUSION_MATRIX Visualizes multi-class confusion matrix mapped to ICDR 0-4
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Inputs:
%   y_true      - Ground truth labels vector (0 to 4)
%   y_pred      - Predicted labels vector (0 to 4)
%   classLabels - Cell array of class names (default: 5 ICDR grades)
%   savePath    - Optional file path to save rendered figure

    if nargin < 3 || isempty(classLabels)
        classLabels = {'0: No DR', '1: Mild', '2: Moderate', '3: Severe', '4: PDR'};
    end

    fig = figure('Name', 'DR Severity Confusion Matrix', 'Visible', 'off');
    cm = confusionchart(y_true, y_pred, 'RowSummary', 'row-normalized', ...
                        'ColumnSummary', 'column-normalized');
    cm.Title = 'Diabetic Retinopathy Grading - Confusion Matrix';
    cm.ClassLabels = classLabels;

    if nargin >= 4 && ~isempty(savePath)
        saveas(fig, savePath);
        fprintf('[Retino-AI] Confusion matrix plot saved to: %s\n', savePath);
    end
end
