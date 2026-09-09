function launch_demo_ui()
% LAUNCH_DEMO_UI Entry point for the Retino-AI local screening interface
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Features:
%   - Image selection / upload
%   - Invocation of analyze_fundus pipeline
%   - Side-by-side display of original vs preprocessed retina
%   - DR severity grading display (Grades 0 to 4)
%   - Visual explainability and clinical recommendation
%
% Note: Currently initializes the demo placeholder UI structure.
% Full interactive App Designer canvas (.mlapp) will connect during Phase 8.

    fprintf('=================================================================\n');
    fprintf('  Retino-AI Demo UI: Explainable DR Screening in Rural India\n');
    fprintf('  SIH26038 - Local Screening Interface\n');
    fprintf('=================================================================\n\n');

    fprintf('Interactive workflow:\n');
    fprintf('  1. Select retinal image (JPEG/PNG/TIFF/DICOM)\n');
    fprintf('  2. Image Quality Gatekeeper audits blur and illumination\n');
    fprintf('  3. Preprocessing standardizes dimensions and extracts green channel\n');
    fprintf('  4. Feature extraction calculates vascular & lesion metrics\n');
    fprintf('  5. Model classifies severity (Grade 0 - 4)\n');
    fprintf('  6. Visual evidence overlay displays lesions & referral advice\n\n');

    % Launch file selector if interactive display is active
    if usejava('jvm') && usejava('awt')
        [file, path] = uigetfile({'*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.dcm', 'Retinal Fundus Images (*.jpg, *.png, *.tif, *.dcm)'}, ...
            'Select Retinal Fundus Photograph for Screening');
        if isequal(file, 0)
            fprintf('[INFO] No image selected. Demo cancelled.\n');
            return;
        end
        imgPath = fullfile(path, file);
        fprintf('[INFO] Selected image: %s\n', imgPath);
        result = analyze_fundus(imgPath);
        disp(result);
    else
        fprintf('[INFO] Running in headless mode. Provide image path directly to analyze_fundus(imagePath).\n');
    end
end
