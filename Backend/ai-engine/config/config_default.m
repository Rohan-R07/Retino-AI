function cfg = config_default()
% CONFIG_DEFAULT Returns base configuration and path parameters for Retino-AI
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Output:
%   cfg - Struct containing paths, image specifications, and grading parameters

    configDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(configDir);

    cfg = struct();
    cfg.project_name = 'Retino-AI';
    cfg.problem_id = 'SIH26038';
    cfg.title = 'Explainable AI for Diabetic Retinopathy Screening in Rural India';

    % Workspace Directory Paths
    cfg.paths.root = rootDir;
    cfg.paths.matlab = fullfile(rootDir, 'matlab');
    cfg.paths.config = configDir;
    cfg.paths.sample_data = fullfile(rootDir, 'sample_data');
    cfg.paths.outputs = fullfile(rootDir, 'outputs');
    cfg.paths.models = fullfile(rootDir, 'matlab', 'models');
    cfg.paths.tests = fullfile(rootDir, 'tests');
    cfg.paths.docs = fullfile(rootDir, 'docs');

    % Image Preprocessing Standards (Planned defaults)
    cfg.image.target_height = 512;
    cfg.image.target_width = 512;
    cfg.image.channels = 3;
    cfg.image.working_channel = 'green'; % Green channel provides optimal lesion contrast

    % ICDR 5-Stage Clinical Severity Scale
    cfg.clinical.grading_scale = {
        '0 - No Apparent DR', ...
        '1 - Mild NPDR', ...
        '2 - Moderate NPDR', ...
        '3 - Severe NPDR', ...
        '4 - Proliferative DR'
    };

    % Referable DR Definition (Clinical standard: Grade 2+ warrants referral)
    cfg.clinical.referral_threshold_grade = 2;
end
