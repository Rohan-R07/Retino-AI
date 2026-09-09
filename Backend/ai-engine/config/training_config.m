function cfg = training_config()
% TRAINING_CONFIG Returns training hyperparameters and experiment settings
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Usage:
%   cfg = training_config();

    configDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(configDir);

    cfg = struct();

    % 1. General Experiment Settings
    cfg.random_seed = 42; % Fixed seed for reproducibility across splits and models
    cfg.experiment_name = 'sih26038_baseline';
    cfg.model_output_dir = fullfile(rootDir, 'outputs', 'models');

    % 2. Image Standards
    cfg.image.target_size = [512, 512]; % [height, width]
    cfg.image.channels = 3;
    cfg.image.working_channel = 'green'; % Green channel for vessel/lesion contrast

    % 3. Dataset Selection & Routing
    % Primary DR Severity Classification
    cfg.dataset.primary_train = 'aptos';      % 'aptos' or 'idrid' or 'combined'
    cfg.dataset.primary_val = 'aptos';
    cfg.dataset.primary_test = 'aptos';

    % External Generalization Testing (Kept independently identifiable)
    cfg.dataset.external_test = 'messidor2';

    % Specialized Tasks
    cfg.dataset.vessel_segmentation = 'drive'; % DRIVE for retinal vessel models
    cfg.dataset.lesion_segmentation = 'idrid'; % IDRiD for pixel lesion masks

    % 4. Split Ratios (For create_splits.m)
    cfg.splits.train_ratio = 0.70;
    cfg.splits.val_ratio = 0.15;
    cfg.splits.test_ratio = 0.15;
    cfg.splits.stratified = true; % Maintain class balance across DR severity grades

    % 5. Classification Targets
    cfg.classification.num_classes = 5;
    cfg.classification.class_labels = {
        '0 - No DR', ...
        '1 - Mild NPDR', ...
        '2 - Moderate NPDR', ...
        '3 - Severe NPDR', ...
        '4 - Proliferative DR'
    };
    cfg.classification.referral_threshold = 2; % Grades >= 2 warrant referral

    % 6. Image Quality Assessment Options (Phase 2)
    cfg.quality.blur_threshold = 25.0;            % Minimum variance of Laplacian within FOV (focus metric)
    cfg.quality.brightness_min = 35.0;            % Minimum mean luminance inside retinal FOV (underexposure)
    cfg.quality.brightness_max = 180.0;           % Maximum mean luminance inside retinal FOV (overexposure)
    cfg.quality.min_entropy = 4.0;                % Minimum Shannon entropy for valid illumination distribution
    cfg.quality.min_fov_ratio = 0.25;             % Minimum retinal coverage ratio (area / total pixels)
    cfg.quality.min_circularity = 0.35;           % Minimum circularity metric of retinal mask

    % 7. Preprocessing Options
    cfg.preprocessing.target_size = cfg.image.target_size; % Inherit standardized prototype size [512, 512]
    cfg.preprocessing.enable_fov_crop = true;
    cfg.preprocessing.fov_padding = 10;                     % Pixel margin around detected FOV
    cfg.preprocessing.enable_illumination_norm = true;
    cfg.preprocessing.illumination_method = 'subtraction';  % 'subtraction' or 'division'
    cfg.preprocessing.illumination_sigma = 30;              % Gaussian kernel std for background estimation
    cfg.preprocessing.enable_clahe = true;
    cfg.preprocessing.clahe_clip_limit = 0.02;             % Contrast clipping limit
    cfg.preprocessing.clahe_distribution = 'rayleigh';     % 'rayleigh', 'uniform', or 'exponential'
    cfg.preprocessing.clahe_num_tiles = [8, 8];            % Contextual grid tiles
    cfg.preprocessing.enable_denoising = true;
    cfg.preprocessing.denoise_method = 'median';           % 'median' (edge-preserving) or 'gaussian'
    cfg.preprocessing.denoise_kernel = [3, 3];             % Filter window [H, W]

    % 8. Feature Extraction Options (Phase 3 Prototype)
    cfg.features.extract_color = true;
    cfg.features.extract_texture = true;
    cfg.features.extract_vessels = true;
    cfg.features.extract_lesions = true;
    cfg.features.texture_glcm_offsets = [0 1; -1 1; -1 0; -1 -1];
    cfg.features.glcm_num_levels = 16;

    % 8. Model Architecture & Selection
    % Options to evaluate: 'random_forest', 'svm', 'ensemble' (Not hardcoded)
    cfg.model.type = 'random_forest'; 
    cfg.model.supported_types = {'random_forest', 'svm', 'ensemble'};
    
    % Random Forest Defaults (TreeBagger)
    cfg.model.rf.num_trees = 150;
    cfg.model.rf.min_leaf_size = 5;
    
    % SVM Defaults (fitcecoc)
    cfg.model.svm.kernel = 'rbf';
    cfg.model.svm.standardize = true;

    % 9. Output Paths
    cfg.paths.saved_models = fullfile(rootDir, 'matlab', 'models', 'saved');
    cfg.paths.evaluation_reports = fullfile(rootDir, 'outputs', 'evaluation');
    cfg.paths.evidence_outputs = fullfile(rootDir, 'outputs', 'evidence');
    cfg.paths.preprocessing_outputs = fullfile(rootDir, 'outputs', 'preprocessing');
    cfg.paths.quality_outputs = fullfile(rootDir, 'outputs', 'quality_assessment');
    cfg.paths.feature_outputs = fullfile(rootDir, 'outputs', 'features');
end
