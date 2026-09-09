function T = create_standard_table(nRows)
% CREATE_STANDARD_TABLE Initializes a standardized MATLAB dataset table
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Schema:
%   image_id         - Unique image identifier (string)
%   image_path       - Absolute or relative file path to fundus image (string)
%   dataset          - Source dataset: 'aptos', 'idrid', 'drive', 'messidor2' (string)
%   dr_grade         - DR severity grade: 0 to 4, or NaN if unlabelled (double)
%   has_dr_label     - Whether image has confirmed clinical DR grade (logical)
%   lesion_mask_path - Path to pixel-level lesion annotation mask or struct (string)
%   vessel_mask_path - Path to ground truth vessel segmentation mask (string)
%   fov_mask_path    - Path to circular field-of-view mask (string)
%   split            - Partition: 'train', 'val', 'test', 'unassigned' (string)
%
% Usage:
%   T = create_standard_table();    % Returns empty table schema (0 rows)
%   T = create_standard_table(100); % Pre-allocates table for 100 rows

    if nargin < 1
        nRows = 0;
    end

    image_id = strings(nRows, 1);
    image_path = strings(nRows, 1);
    dataset = strings(nRows, 1);
    dr_grade = nan(nRows, 1);
    has_dr_label = false(nRows, 1);
    lesion_mask_path = strings(nRows, 1);
    vessel_mask_path = strings(nRows, 1);
    fov_mask_path = strings(nRows, 1);
    split = repmat("unassigned", nRows, 1);

    T = table(image_id, image_path, dataset, dr_grade, has_dr_label, ...
              lesion_mask_path, vessel_mask_path, fov_mask_path, split);
end
