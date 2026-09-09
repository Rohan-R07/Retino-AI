function cfg = dataset_config(customConfigFile)
% DATASET_CONFIG Loads dataset path configurations for Retino-AI
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Datasets Supported:
%   1. APTOS 2019 Blindness Detection (Classification: 5 grades)
%   2. IDRiD (Disease Grading, Segmentation, Localization)
%   3. DRIVE (Vessel Segmentation + FOV Masks: 40 images)
%   4. Messidor-2 (External Evaluation & Generalization Testing - OPTIONAL)
%
% Usage:
%   cfg = dataset_config();
%   cfg = dataset_config('custom_datasets.json');

    configDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(configDir);
    defaultJson = fullfile(configDir, 'datasets.json');

    if nargin < 1 || isempty(customConfigFile)
        configFile = defaultJson;
    else
        configFile = customConfigFile;
    end

    % Base structure
    cfg = struct();
    cfg.root_dir = rootDir;
    cfg.data_root = fullfile(rootDir, 'data');
    cfg.raw_root = fullfile(rootDir, 'data', 'raw');
    cfg.processed_root = fullfile(rootDir, 'data', 'processed');
    cfg.splits_root = fullfile(rootDir, 'data', 'splits');

    % Read from JSON if present
    jsonConf = struct();
    if exist(configFile, 'file') == 2
        try
            fileContent = fileread(configFile);
            jsonConf = jsondecode(fileContent);
        catch ME
            warning('RetinoAI:ConfigReadError', ...
                'Failed to parse %s: %s. Using default configuration.', configFile, ME.message);
        end
    end

    % -------------------------------------------------------------
    % 1. APTOS Configuration
    % -------------------------------------------------------------
    cfg.aptos = struct();
    cfg.aptos.enabled = getFieldOrDefault(jsonConf, {'aptos', 'enabled'}, true);
    cfg.aptos.optional = false;
    cfg.aptos.name = 'APTOS 2019 Blindness Detection';
    cfg.aptos.task = '5-Class DR Severity Classification';
    cfg.aptos.num_classes = 5;
    cfg.aptos.class_labels = {'0 - No DR', '1 - Mild', '2 - Moderate', '3 - Severe', '4 - Proliferative'};
    
    rawAptosRoot = getFieldOrDefault(jsonConf, {'aptos', 'root'}, fullfile(cfg.raw_root, 'aptos'));
    cfg.aptos.root = resolvePath(rawAptosRoot, rootDir);
    
    rawAptosLabels = getFieldOrDefault(jsonConf, {'aptos', 'labels'}, 'train.csv');
    cfg.aptos.labels = resolvePath(rawAptosLabels, cfg.aptos.root);
    
    rawAptosImages = getFieldOrDefault(jsonConf, {'aptos', 'images'}, 'train_images');
    cfg.aptos.images = resolvePath(rawAptosImages, cfg.aptos.root);

    % -------------------------------------------------------------
    % 2. IDRiD Configuration
    % -------------------------------------------------------------
    cfg.idrid = struct();
    cfg.idrid.enabled = getFieldOrDefault(jsonConf, {'idrid', 'enabled'}, true);
    cfg.idrid.optional = false;
    cfg.idrid.name = 'Indian Diabetic Retinopathy Image Dataset (IDRiD)';
    cfg.idrid.task = 'DR Grading, Lesion Segmentation, Anatomical Localization';
    cfg.idrid.num_classes = 5;
    cfg.idrid.class_labels = {'0 - No DR', '1 - Mild', '2 - Moderate', '3 - Severe', '4 - Proliferative'};
    cfg.idrid.supported_lesions = {'Microaneurysms', 'Haemorrhages', 'Hard Exudates', 'Soft Exudates', 'Optic Disc'};
    
    rawIdridRoot = getFieldOrDefault(jsonConf, {'idrid', 'root'}, fullfile(cfg.raw_root, 'idrid'));
    cfg.idrid.root = resolvePath(rawIdridRoot, rootDir);
    
    % Disease Grading Paths
    cfg.idrid.grading_dir = fullfile(cfg.idrid.root, 'Disease Grading');
    cfg.idrid.grading_train_labels = fullfile(cfg.idrid.grading_dir, '2. Groundtruths', 'a. IDRiD_Disease Grading_Training Labels.csv');
    cfg.idrid.grading_test_labels = fullfile(cfg.idrid.grading_dir, '2. Groundtruths', 'b. IDRiD_Disease Grading_Testing Labels.csv');
    cfg.idrid.grading_train_images = fullfile(cfg.idrid.grading_dir, '1. Original Images', 'a. Training Set');
    cfg.idrid.grading_test_images = fullfile(cfg.idrid.grading_dir, '1. Original Images', 'b. Testing Set');
    
    % Legacy aliases for single-path queries
    rawIdridGrading = getFieldOrDefault(jsonConf, {'idrid', 'grading_labels'}, '');
    if ~isempty(rawIdridGrading)
        cfg.idrid.grading_labels = resolvePath(rawIdridGrading, cfg.idrid.root);
    else
        cfg.idrid.grading_labels = cfg.idrid.grading_train_labels;
    end
    rawIdridImages = getFieldOrDefault(jsonConf, {'idrid', 'images'}, '');
    if ~isempty(rawIdridImages)
        cfg.idrid.images = resolvePath(rawIdridImages, cfg.idrid.root);
    else
        cfg.idrid.images = cfg.idrid.grading_train_images;
    end

    % Segmentation Paths
    cfg.idrid.segmentation_dir = fullfile(cfg.idrid.root, 'Segmentation');
    cfg.idrid.segmentation_train_images = fullfile(cfg.idrid.segmentation_dir, '1. Original Images', 'a. Training Set');
    cfg.idrid.segmentation_test_images = fullfile(cfg.idrid.segmentation_dir, '1. Original Images', 'b. Testing Set');
    cfg.idrid.segmentation_train_masks = fullfile(cfg.idrid.segmentation_dir, '2. All Segmentation Groundtruths', 'a. Training Set');
    cfg.idrid.segmentation_test_masks = fullfile(cfg.idrid.segmentation_dir, '2. All Segmentation Groundtruths', 'b. Testing Set');
    cfg.idrid.lesion_masks = cfg.idrid.segmentation_train_masks;

    % Localization Paths
    cfg.idrid.localization_dir = fullfile(cfg.idrid.root, 'Localization');
    cfg.idrid.localization_train_images = fullfile(cfg.idrid.localization_dir, '1. Original Images', 'a. Training Set');
    cfg.idrid.localization_test_images = fullfile(cfg.idrid.localization_dir, '1. Original Images', 'b. Testing Set');
    cfg.idrid.localization_od_train = fullfile(cfg.idrid.localization_dir, '2. Groundtruths', '1. Optic Disc Center Location', 'a. IDRiD_OD_Center_Training Set_Markups.csv');
    cfg.idrid.localization_od_test = fullfile(cfg.idrid.localization_dir, '2. Groundtruths', '1. Optic Disc Center Location', 'b. IDRiD_OD_Center_Testing Set_Markups.csv');
    cfg.idrid.localization_fovea_train = fullfile(cfg.idrid.localization_dir, '2. Groundtruths', '2. Fovea Center Location', 'IDRiD_Fovea_Center_Training Set_Markups.csv');
    cfg.idrid.localization_fovea_test = fullfile(cfg.idrid.localization_dir, '2. Groundtruths', '2. Fovea Center Location', 'IDRiD_Fovea_Center_Testing Set_Markups.csv');

    % -------------------------------------------------------------
    % 3. DRIVE Configuration
    % -------------------------------------------------------------
    cfg.drive = struct();
    cfg.drive.enabled = getFieldOrDefault(jsonConf, {'drive', 'enabled'}, true);
    cfg.drive.optional = false;
    cfg.drive.name = 'Digital Retinal Images for Vessel Extraction (DRIVE)';
    cfg.drive.task = 'Retinal Vessel Segmentation';
    cfg.drive.total_images = 40;
    
    rawDriveRoot = getFieldOrDefault(jsonConf, {'drive', 'root'}, fullfile(cfg.raw_root, 'drive'));
    cfg.drive.root = resolvePath(rawDriveRoot, rootDir);

    cfg.drive.training_images = fullfile(cfg.drive.root, 'training', 'images');
    cfg.drive.training_vessel_masks = fullfile(cfg.drive.root, 'training', '1st_manual');
    cfg.drive.training_fov_masks = fullfile(cfg.drive.root, 'training', 'mask');
    cfg.drive.test_images = fullfile(cfg.drive.root, 'test', 'images');
    cfg.drive.test_fov_masks = fullfile(cfg.drive.root, 'test', 'mask');
    
    % Aliases
    cfg.drive.images = cfg.drive.training_images;
    cfg.drive.vessel_masks = cfg.drive.training_vessel_masks;
    cfg.drive.fov_masks = cfg.drive.training_fov_masks;

    % -------------------------------------------------------------
    % 4. Messidor-2 Configuration (OPTIONAL / UNAVAILABLE)
    % -------------------------------------------------------------
    cfg.messidor2 = struct();
    % Messidor-2 is optional and currently not downloaded
    cfg.messidor2.enabled = getFieldOrDefault(jsonConf, {'messidor2', 'enabled'}, false);
    cfg.messidor2.optional = true;
    cfg.messidor2.name = 'Messidor-2 (External Cohort)';
    cfg.messidor2.task = 'External Generalization & Validation';
    
    rawMessidorRoot = getFieldOrDefault(jsonConf, {'messidor2', 'root'}, fullfile(cfg.raw_root, 'messidor2'));
    cfg.messidor2.root = resolvePath(rawMessidorRoot, rootDir);
    cfg.messidor2.labels = getFieldOrDefault(jsonConf, {'messidor2', 'labels'}, '');
    cfg.messidor2.images = getFieldOrDefault(jsonConf, {'messidor2', 'images'}, '');
end

function val = getFieldOrDefault(s, fields, defaultVal)
    val = defaultVal;
    curr = s;
    for i = 1:numel(fields)
        f = fields{i};
        if isstruct(curr) && isfield(curr, f)
            curr = curr.(f);
        else
            return;
        end
    end
    if ischar(curr) || isstring(curr)
        if strlength(curr) > 0
            val = char(curr);
        end
    elseif ~isempty(curr)
        val = curr;
    end
end

function absPath = resolvePath(p, baseDir)
    if isempty(p)
        absPath = '';
        return;
    end
    % Check if path is absolute
    isAbs = false;
    if (numel(p) >= 2 && p(2) == ':') || (numel(p) >= 1 && (p(1) == '/' || p(1) == '\'))
        isAbs = true;
    end

    if isAbs
        absPath = p;
    else
        absPath = fullfile(baseDir, p);
    end
end
