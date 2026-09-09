function explanation = generate_explanation(origImg, predictedGrade, detectedLesions, vesselInfo, featureTable)
% GENERATE_EXPLANATION Assembles human-interpretable clinical explanation and visual evidence
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Produces:
%   1. Visual evidence overlay image
%   2. Structured clinical justification text explaining the assigned ICDR grade
%   3. Key quantitative biomarker summary (lesion counts, vessel density)
%
% Note: Does not use opaque Grad-CAM or fake heatmaps. Rationale is anchored in
% concrete clinical biomarkers extracted from the retina.
%
% Output:
%   explanation - Struct containing visual overlay, clinical text, and biomarker summary

    if nargin < 3, detectedLesions = struct(); end
    if nargin < 4, vesselInfo = struct(); end
    if nargin < 5, featureTable = table(); end

    explanation = struct();

    % 1. Visual evidence image
    explanation.visual_evidence_image = generate_evidence_overlay(origImg, detectedLesions, vesselInfo);

    % 2. Clinical narrative generator
    gradeNames = {
        'No Apparent Diabetic Retinopathy', ...
        'Mild Non-Proliferative Diabetic Retinopathy', ...
        'Moderate Non-Proliferative Diabetic Retinopathy', ...
        'Severe Non-Proliferative Diabetic Retinopathy', ...
        'Proliferative Diabetic Retinopathy'
    };

    if isnan(predictedGrade) || predictedGrade < 0 || predictedGrade > 4
        explanation.clinical_narrative = 'Prediction uninitialized. Model has not been trained yet.';
        explanation.referral_recommended = false;
        return;
    end

    gradeIdx = predictedGrade + 1;
    explanation.grade_name = gradeNames{gradeIdx};
    explanation.referral_recommended = (predictedGrade >= 2);

    % Detail clinical rationale
    switch predictedGrade
        case 0
            narrative = 'No clinically significant microaneurysms, hemorrhages, or exudative lesions detected within the field of view. Routine annual follow-up advised.';
        case 1
            narrative = 'Isolated microaneurysms detected without widespread intraretinal hemorrhages or lipid exudation. Early stage NPDR; 6-month monitoring recommended.';
        case 2
            narrative = 'Multiple microaneurysms, dot/blot hemorrhages, or hard exudates identified. Moderate NPDR threshold reached. Referral to ophthalmologist recommended.';
        case 3
            narrative = 'Extensive intraretinal hemorrhages or microvascular abnormalities observed across multiple quadrants. Severe NPDR; urgent ophthalmology referral required.';
        case 4
            narrative = 'Evidence of neovascularization or preretinal/vitreous hemorrhage detected. Proliferative Diabetic Retinopathy; immediate tertiary eye care intervention required.';
    end

    explanation.clinical_narrative = narrative;
    explanation.biomarker_summary.detected_lesions = detectedLesions;
    explanation.biomarker_summary.vessel_info = vesselInfo;
end
