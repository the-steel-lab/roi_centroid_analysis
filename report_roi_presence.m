% report_roi_presence.m
%
% Generates a presence/absence table showing which ROIs were defined for
% each participant, separated by study, task, and hemisphere.
%
% Run run_roi_analysis.m (Dartmouth) and run_roi_analysis_ed.m (Edinburgh)
% before running this script.
%
% OUTPUTS:
%   Console tables printed for each study × task × hemisphere combination.
%   CSV files saved to output/<Study>/roi_presence_<study>_<task>_<hemi>.csv

clear; clc;

output_root = fullfile(pwd, 'output');

mat_files = {
    fullfile(output_root, 'Dartmouth',  'results_roi_analysis_Dartmouth.mat');
    fullfile(output_root, 'Edinburgh',  'results_roi_analysis_Edinburgh.mat');
};

for fi = 1:numel(mat_files)
    mat_path = mat_files{fi};

    if ~exist(mat_path, 'file')
        fprintf('WARNING: File not found, skipping: %s\n\n', mat_path);
        continue;
    end

    loaded   = load(mat_path, 'results', 'cfg');
    results  = loaded.results;
    cfg      = loaded.cfg;

    study      = cfg.study;
    subjects   = cfg.subjects;
    hemis      = cfg.hemis;
    roi_list   = cfg.roi_list;
    task_names = {cfg.tasks.name};

    nSubj  = numel(subjects);
    nROI   = numel(roi_list);
    nHemi  = numel(hemis);
    nTask  = numel(task_names);

    % Build ROI label list (fall back to "ROI<N>" if name not supplied)
    roi_labels = cell(1, nROI);
    for ri = 1:nROI
        if isfield(cfg, 'roi_names') && ri <= numel(cfg.roi_names)
            roi_labels{ri} = cfg.roi_names{ri};
        else
            roi_labels{ri} = sprintf('ROI%d', roi_list(ri));
        end
    end

    fprintf('\n%s\n', repmat('=', 1, 70));
    fprintf('  STUDY: %s\n', study);
    fprintf('%s\n', repmat('=', 1, 70));

    for ti = 1:nTask
        tname = task_names{ti};

        fprintf('\n  Task: %s\n', tname);
        fprintf('  %s\n', repmat('-', 1, 66));

        for hi = 1:nHemi
            hemi = hemis{hi};

            % Build nSubj x nROI presence matrix
            presence = false(nSubj, nROI);
            for ri = 1:nROI
                cent_mat = results.roi(ri).centroid.(tname);  % [nSubj x 3 x nHemi]
                % Present if first coordinate is not NaN
                presence(:, ri) = ~isnan(cent_mat(:, 1, hi));
            end

            counts = sum(presence, 1);  % 1 x nROI

            % ---- Console table ----
            col_w  = 10;
            subj_w = 12;

            % Header
            fprintf('\n  Hemisphere: %s\n\n', upper(hemi));
            header = sprintf('  %-*s', subj_w, 'Subject');
            for ri = 1:nROI
                header = [header sprintf(' | %-*s', col_w, roi_labels{ri})]; %#ok<AGROW>
            end
            fprintf('%s\n', header);
            fprintf('  %s\n', repmat('-', 1, subj_w + (col_w + 3) * nROI));

            for si = 1:nSubj
                row = sprintf('  %-*s', subj_w, subjects{si});
                for ri = 1:nROI
                    if presence(si, ri)
                        val = '1';
                    else
                        val = '0';
                    end
                    row = [row sprintf(' | %-*s', col_w, val)]; %#ok<AGROW>
                end
                fprintf('%s\n', row);
            end

            % Count row
            fprintf('  %s\n', repmat('-', 1, subj_w + (col_w + 3) * nROI));
            count_row = sprintf('  %-*s', subj_w, sprintf('COUNT (n=%d)', nSubj));
            for ri = 1:nROI
                count_row = [count_row sprintf(' | %-*s', col_w, ...
                    sprintf('%d/%d', counts(ri), nSubj))]; %#ok<AGROW>
            end
            fprintf('%s\n\n', count_row);

            % ---- CSV ----
            csv_name = sprintf('roi_presence_%s_%s_%s.csv', study, tname, hemi);
            csv_path = fullfile(output_root, study, csv_name);

            fid = fopen(csv_path, 'w');
            % Header row
            fprintf(fid, 'Subject');
            for ri = 1:nROI
                fprintf(fid, ',%s', roi_labels{ri});
            end
            fprintf(fid, '\n');
            % Data rows
            for si = 1:nSubj
                fprintf(fid, '%s', subjects{si});
                for ri = 1:nROI
                    fprintf(fid, ',%d', presence(si, ri));
                end
                fprintf(fid, '\n');
            end
            % Count row
            fprintf(fid, 'COUNT (n=%d)', nSubj);
            for ri = 1:nROI
                fprintf(fid, ',%d/%d', counts(ri), nSubj);
            end
            fprintf(fid, '\n');
            fclose(fid);

            fprintf('  CSV saved: %s\n', csv_path);
        end % hemispheres
    end % tasks
end % studies

fprintf('\nDone.\n');
