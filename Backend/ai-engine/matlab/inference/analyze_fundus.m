function result = analyze_fundus(imagePath, modelPath, cfg)
% ANALYZE_FUNDUS Master single-image end-to-end inference pipeline interface
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Architecture Flow:
%   Raw Image
%       ↓
%   Quality Assessment Gatekeeper (check focus, illumination, FOV)
%       ↓ (if gradable)
%   Preprocessing (crop FOV, resize, green channel, CLAHE)
%       ↓
%   Feature Extraction (color moments, texture, vessels, lesions)
%       ↓
%   Model Inference (Random Forest / SVM multi-class prediction)
%       ↓
%   Visual Explainability & Clinical Narrative Generation
%       ↓
%   Structured Diagnostic Result (ready for rural health report & API)
%
% Usage:
%   result = analyze_fundus('sample_data/test_eye.jpg');
%   result = analyze_fundus(imgPath, modelStruct, customConfig);
%
% Output:
%   result - Struct with gradability, DR grade (0-4), confidence, referral, and explanation

    if nargin < 2, modelPath = ''; end
    if nargin < 3, cfg = struct(); end

    fprintf('[Retino-AI] Analyzing fundus image: %s\n', imagePath);

    result = struct();
    result.image_path = imagePath;
    result.timestamp = datestr(now);
    result.is_gradable = false;
    result.dr_grade = NaN;
    result.dr_label = 'Unassigned';
    result.confidence = 0.0;
    result.referral_recommended = false;
    result.explanation = struct();

    % Step 1: Quality Assessment Gatekeeper
    quality = assess_image_quality(imagePath);
    result.quality = quality;

    if ~quality.is_gradable
        fprintf('[Retino-AI] Image is UNGRADABLE. Halting inference.\n');
        result.status = 'UNGRADABLE';
        result.advisory = quality.advisory_message;
        return;
    end

    result.is_gradable = true;

    % Step 2: Preprocessing
    processed = preprocess_fundus(imagePath);
    result.preprocessed_summary = processed.metadata;

    % Step 3: Feature Extraction
    features = extract_features(processed);
    result.num_features_extracted = features.num_features;

    % Step 4: Model Inference (Phase 8 execution)
    % When model is uninitialized, report status cleanly without fake predictions
    if isempty(modelPath)
        result.status = 'READY_FOR_TRAINED_MODEL';
        result.message = 'Pipeline executed through feature extraction. Model training will occur in Phase 5.';
        return;
    end

    % Execution with loaded model
    [predictedGrade, conf] = predict_dr_grade(modelPath, features.table);
    result.dr_grade = predictedGrade;
    result.confidence = conf;
    result.referral_recommended = (predictedGrade >= 2);

    % Step 5: Explainability Generation
    explanation = generate_explanation(processed.original, predictedGrade, ...
        features.categories.lesions, features.categories.vessels, features.table);
    result.explanation = explanation;
    result.status = 'ANALYSIS_COMPLETE';
end
