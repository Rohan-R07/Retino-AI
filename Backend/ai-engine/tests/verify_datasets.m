function report = verify_datasets(customConfig)
% VERIFY_DATASETS Audits local availability and integrity of all four datasets
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Checks:
%   - APTOS 2019: train.csv exists, training images exist, image IDs match labels, grades 0-4
%   - IDRiD: Disease Grading (train/test), Segmentation (5 lesion types), Localization (OD/Fovea)
%   - DRIVE: training images (20), vessel masks (20), test images (20), FOV masks (40)
%   - Messidor-2: Treated as optional / skipped without failing verification
%
% Usage:
%   report = verify_datasets();

    if nargin < 1 || isempty(customConfig)
        cfg = dataset_config();
    else
        cfg = customConfig;
    end

    fprintf('====================================\n');
    fprintf('        DATASET VERIFICATION        \n');
    fprintf('====================================\n\n');

    report = struct();
    report.all_passed = false;

    % -------------------------------------------------------------
    % 1. APTOS 2019
    % -------------------------------------------------------------
    fprintf('APTOS (2019 Blindness Detection)\n');
    [tAptos, rAptos] = load_aptos(cfg);
    report.aptos = rAptos;

    if rAptos.is_available && isempty(rAptos.missing_images) && isempty(rAptos.invalid_labels)
        aptosStatus = 'READY';
    elseif rAptos.is_available
        aptosStatus = 'PARTIALLY_AVAILABLE (mismatches detected)';
    else
        aptosStatus = 'NOT CONFIGURED / MISSING';
    end

    fprintf('  Images: %d\n', rAptos.num_images_found);
    fprintf('  Labels: %d\n', rAptos.num_labels_found);
    fprintf('  Missing: %d\n', numel(rAptos.missing_images));
    fprintf('  Status: %s\n\n', aptosStatus);

    % -------------------------------------------------------------
    % 2. IDRiD
    % -------------------------------------------------------------
    fprintf('IDRiD (Indian Diabetic Retinopathy Image Dataset)\n');
    [tIdrid, rIdrid] = load_idrid(cfg);
    report.idrid = rIdrid;

    if rIdrid.is_available && rIdrid.has_disease_grading && rIdrid.has_segmentation
        idridStatus = 'READY';
    elseif rIdrid.has_disease_grading
        idridStatus = 'PARTIALLY_AVAILABLE (Grading ready, segmentation incomplete)';
    else
        idridStatus = 'NOT CONFIGURED / MISSING';
    end

    fprintf('  Disease Grading Images: %d (%d train + %d test)\n', ...
        rIdrid.num_images_found, rIdrid.grading.train_images, rIdrid.grading.test_images);
    fprintf('  Disease Grading Labels: %d (%d train + %d test)\n', ...
        rIdrid.num_labels_found, rIdrid.grading.train_labels, rIdrid.grading.test_labels);
    fprintf('  Segmentation Images: %d (%d train + %d test)\n', ...
        rIdrid.segmentation.train_images + rIdrid.segmentation.test_images, ...
        rIdrid.segmentation.train_images, rIdrid.segmentation.test_images);
    fprintf('  Lesion Masks: %d (MA: %d, HE: %d, EX: %d, SE: %d, OD: %d)\n', ...
        rIdrid.num_lesion_masks_found, ...
        rIdrid.segmentation.masks_detected.microaneurysms, ...
        rIdrid.segmentation.masks_detected.haemorrhages, ...
        rIdrid.segmentation.masks_detected.hard_exudates, ...
        rIdrid.segmentation.masks_detected.soft_exudates, ...
        rIdrid.segmentation.masks_detected.optic_disc);
    fprintf('  Localization Data: OD (%d train + %d test), Fovea (%d train + %d test)\n', ...
        rIdrid.localization.od_train_rows, rIdrid.localization.od_test_rows, ...
        rIdrid.localization.fovea_train_rows, rIdrid.localization.fovea_test_rows);
    fprintf('  Status: %s\n\n', idridStatus);

    % -------------------------------------------------------------
    % 3. DRIVE
    % -------------------------------------------------------------
    fprintf('DRIVE (Digital Retinal Images for Vessel Extraction)\n');
    [tDrive, rDrive] = load_drive(cfg);
    report.drive = rDrive;

    if rDrive.is_available && rDrive.training_vessel_masks_found == 20 && rDrive.num_images_found == 40
        driveStatus = 'READY';
    elseif rDrive.is_available
        driveStatus = 'PARTIALLY_AVAILABLE';
    else
        driveStatus = 'NOT CONFIGURED / MISSING';
    end

    fprintf('  Training Images: %d\n', rDrive.training_images_found);
    fprintf('  Training Vessel Masks: %d\n', rDrive.training_vessel_masks_found);
    fprintf('  Test Images: %d\n', rDrive.test_images_found);
    fprintf('  FOV Masks: %d (%d train + %d test)\n', ...
        rDrive.training_fov_masks_found + rDrive.test_fov_masks_found, ...
        rDrive.training_fov_masks_found, rDrive.test_fov_masks_found);
    fprintf('  Status: %s\n\n', driveStatus);

    % -------------------------------------------------------------
    % 4. Messidor-2 (OPTIONAL)
    % -------------------------------------------------------------
    fprintf('MESSIDOR-2 (External Generalization Dataset - Optional)\n');
    [tMessidor, rMessidor] = load_messidor2(cfg);
    report.messidor2 = rMessidor;

    if rMessidor.is_available
        messidorStatus = 'READY';
        fprintf('  Images: %d\n', rMessidor.num_images_found);
        fprintf('  Labels: %d\n', rMessidor.num_labels_found);
    else
        messidorStatus = 'SKIPPED (Optional - not downloaded yet)';
        fprintf('  Notice: Messidor-2 is optional and not currently installed.\n');
    end
    fprintf('  Status: %s\n\n', messidorStatus);

    % -------------------------------------------------------------
    % Summary Verdict
    % -------------------------------------------------------------
    fprintf('====================================\n');
    readyCount = strcmp(aptosStatus, 'READY') + ...
                 strcmp(idridStatus, 'READY') + ...
                 strcmp(driveStatus, 'READY');

    if readyCount == 3
        report.all_passed = true;
        fprintf(' VERIFICATION PASSED: All 3 active datasets (APTOS, IDRiD, DRIVE) are READY.\n');
        fprintf(' Messidor-2 is safely handled as optional.\n');
    else
        report.all_passed = false;
        fprintf(' VERIFICATION WARNING: %d/3 primary datasets are READY.\n', readyCount);
    end
    fprintf('====================================\n');
end
