% run_roi_analysis.m
%
% Master script for ROI centroid analysis pipeline.
%
% PURPOSE:
%   Compares surface-based fMRI ROI centroids across two task conditions
%   across subjects and hemispheres. Computes centroid positions, centroid
%   shifts (task1 - task2), and vertex-level Jaccard overlap between tasks.
%   Produces bar plots of centroid shift and polar (Y-Z plane) plots.
%
% USAGE:
%   Edit the USER CONFIGURATION section below, then run this script.
%   All function dependencies are in the 'functions/' subdirectory.
%
% OUTPUT:
%   <output_dir>/results_roi_analysis.mat  : saved results struct
%   <output_dir>/figures_centroid_shift/   : bar plot PNGs per ROI
%   <output_dir>/figures_polar/            : polar plot PNGs per ROI

clear; clc;

%% =====================================================================
%  USER CONFIGURATION — edit this section only
%% =====================================================================
cfg = struct();

cfg.subjects = {
    'scim001','scim002','scim008','scim012','scim014','scim076', ...
    'scim257','scim297','scim312','scim357','scim0989','scim995'
};

cfg.hemis    = {'lh', 'rh'};
cfg.roi_list = 39:43;

cfg.base_dir   = '/path/to/your/data';   % <-- CHANGE THIS
cfg.output_dir = fullfile(pwd, 'output');

% Task 1 (minuend in diff matrix: task1 - task2)
cfg.tasks(1).name            = 'imagery';
cfg.tasks(1).subdir          = 'imagery';
cfg.tasks(1).roi_stem        = 'nicole-final-roi';
cfg.tasks(1).coords_filename = 'ref.{hemi}.inflated.coords.1D';

% Task 2 (subtrahend in diff matrix)
cfg.tasks(2).name            = 'dynloc';
cfg.tasks(2).subdir          = 'dynloc';
cfg.tasks(2).roi_stem        = 'nicole-new-roi';
cfg.tasks(2).coords_filename = 'ref.{hemi}.inflated.coords.1D';
%% =====================================================================

%% Setup
addpath(fullfile(fileparts(mfilename('fullpath')), 'functions'));

if ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
    fprintf('Created output directory: %s\n', cfg.output_dir);
end

%% Load per-subject, per-hemisphere, per-task ROI data
fprintf('\n=== Loading ROI data ===\n');

subjectData = struct();

for si = 1:numel(cfg.subjects)
    subj = cfg.subjects{si};

    for hi = 1:numel(cfg.hemis)
        hemi = cfg.hemis{hi};

        for ti = 1:numel(cfg.tasks)
            task = cfg.tasks(ti);

            % Resolve {hemi} placeholder in coords_filename
            resolved_coords = strrep(task.coords_filename, '{hemi}', hemi);

            % Build full file paths
            coords_path = fullfile(cfg.base_dir, subj, resolved_coords);
            roi_filename = ['ref.' task.roi_stem '-' hemi '.1D.roi'];
            roi_path     = fullfile(cfg.base_dir, subj, task.subdir, roi_filename);

            fprintf('  Loading: subj=%s  hemi=%s  task=%s\n', subj, hemi, task.name);

            try
                S = load_roi_data(roi_path, coords_path, cfg.roi_list);
                subjectData.(hemi).(subj).(task.name) = S;
            catch ME
                warning('run_roi_analysis:loadFailed', ...
                    'Failed to load subj=%s hemi=%s task=%s: %s', ...
                    subj, hemi, task.name, ME.message);
                % Store empty sentinel so downstream code can detect absence
                S_empty = struct();
                S_empty.missing       = true;
                S_empty.coords_missing = true;
                S_empty.roi_numbers   = [];
                S_empty.vertices      = {};
                S_empty.coords        = {};
                S_empty.centroid      = {};
                subjectData.(hemi).(subj).(task.name) = S_empty;
            end
        end % tasks
    end % hemis
end % subjects

%% Build group matrices
fprintf('\n=== Building group matrices ===\n');
results = build_group_matrices(subjectData, cfg);

%% Compute vertex-level Jaccard overlap
fprintf('\n=== Computing vertex-level overlap ===\n');
results = compute_overlap(results, subjectData, cfg);

%% Save results
save_path = fullfile(cfg.output_dir, 'results_roi_analysis.mat');
save(save_path, 'results', 'cfg');
fprintf('\nResults saved to: %s\n', save_path);

%% Plot
fprintf('\n=== Plotting results ===\n');
plot_results(results, cfg);

fprintf('\n=== Pipeline complete ===\n');
