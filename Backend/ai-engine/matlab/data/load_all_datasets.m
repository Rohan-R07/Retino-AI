function [combinedTable, datasetReports] = load_all_datasets(customConfig)
% LOAD_ALL_DATASETS Orchestrates loading across all configured DR datasets
% Project: SIH26038 - Explainable AI for Diabetic Retinopathy Screening in Rural India
%
% Datasets Supported:
%   1. APTOS 2019 Blindness Detection
%   2. IDRiD
%   3. DRIVE
%   4. Messidor-2
%
% Output:
%   combinedTable  - Unified standardized MATLAB table of all available images
%   datasetReports - Struct containing individual dataset tables and status audits

    if nargin < 1 || isempty(customConfig)
        cfg = dataset_config();
    else
        cfg = customConfig;
    end

    fprintf('=================================================================\n');
    fprintf('  Retino-AI: Loading Configured Datasets\n');
    fprintf('=================================================================\n');

    datasetReports = struct();
    tablesList = {};

    % 1. APTOS
    if cfg.aptos.enabled
        fprintf('[LOADER] Querying APTOS 2019...\n');
        [tAptos, rAptos] = load_aptos(cfg);
        datasetReports.aptos.table = tAptos;
        datasetReports.aptos.report = rAptos;
        if height(tAptos) > 0
            tablesList{end+1} = tAptos;
            fprintf('  -> APTOS: %d images loaded.\n', height(tAptos));
        else
            fprintf('  -> APTOS: Not found / 0 images loaded. (%s)\n', rAptos.message);
        end
    end

    % 2. IDRiD
    if cfg.idrid.enabled
        fprintf('[LOADER] Querying IDRiD...\n');
        [tIdrid, rIdrid] = load_idrid(cfg);
        datasetReports.idrid.table = tIdrid;
        datasetReports.idrid.report = rIdrid;
        if height(tIdrid) > 0
            tablesList{end+1} = tIdrid;
            fprintf('  -> IDRiD: %d images loaded.\n', height(tIdrid));
        else
            fprintf('  -> IDRiD: Not found / 0 images loaded. (%s)\n', rIdrid.message);
        end
    end

    % 3. DRIVE
    if cfg.drive.enabled
        fprintf('[LOADER] Querying DRIVE...\n');
        [tDrive, rDrive] = load_drive(cfg);
        datasetReports.drive.table = tDrive;
        datasetReports.drive.report = rDrive;
        if height(tDrive) > 0
            tablesList{end+1} = tDrive;
            fprintf('  -> DRIVE: %d images loaded.\n', height(tDrive));
        else
            fprintf('  -> DRIVE: Not found / 0 images loaded. (%s)\n', rDrive.message);
        end
    end

    % 4. Messidor-2 (Optional)
    if isfield(cfg.messidor2, 'enabled') && cfg.messidor2.enabled
        fprintf('[LOADER] Querying Messidor-2...\n');
        [tMessidor, rMessidor] = load_messidor2(cfg);
        datasetReports.messidor2.table = tMessidor;
        datasetReports.messidor2.report = rMessidor;
        if height(tMessidor) > 0
            tablesList{end+1} = tMessidor;
            fprintf('  -> Messidor-2: %d images loaded for external evaluation.\n', height(tMessidor));
        else
            fprintf('  -> Messidor-2: Not found / 0 images loaded. (%s)\n', rMessidor.message);
        end
    else
        fprintf('[LOADER] Messidor-2: Skipped (Optional external cohort not downloaded yet).\n');
        datasetReports.messidor2.table = create_standard_table();
        datasetReports.messidor2.report = struct('dataset', 'messidor2', 'is_available', false, ...
            'is_optional', true, 'status', 'SKIPPED (Optional - not downloaded yet)');
    end

    % Concatenate all available tables
    if ~isempty(tablesList)
        combinedTable = vertcat(tablesList{:});
    else
        combinedTable = create_standard_table();
    end

    fprintf('-----------------------------------------------------------------\n');
    fprintf(' Total Images Available Across Datasets: %d\n', height(combinedTable));
    fprintf('=================================================================\n\n');
end
