function results = run_all_tests()
% RUN_ALL_TESTS Master test runner for Retino-AI engine
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Usage:
%   run_all_tests();

    testsDir = fileparts(mfilename('fullpath'));
    matlabDir = fullfile(fileparts(testsDir), 'matlab');
    
    % Ensure paths are loaded
    if exist(fullfile(matlabDir, 'setup_paths.m'), 'file') == 2
        run(fullfile(matlabDir, 'setup_paths.m'));
    end

    fprintf('\n[Retino-AI] Executing Environment Health Verification...\n');
    envReport = verify_environment();

    fprintf('\n[Retino-AI] Executing Dataset Audit...\n');
    datasetReport = verify_datasets();

    fprintf('\n[Retino-AI] Executing Preprocessing Pipeline Verification...\n');
    prepReport = test_preprocessing();

    fprintf('\n[Retino-AI] Executing Image Quality Assessment Verification...\n');
    qaReport = test_quality_assessment();

    fprintf('\n[Retino-AI] Executing Feature Extraction Verification...\n');
    featReport = test_feature_extraction();

    fprintf('\n[Retino-AI] Executing Model Inference Verification...\n');
    infReport = test_model_inference();

    if nargout > 0
        results.environment = envReport;
        results.datasets = datasetReport;
        results.preprocessing = prepReport;
        results.quality_assessment = qaReport;
        results.features = featReport;
        results.inference = infReport;
    end
end
