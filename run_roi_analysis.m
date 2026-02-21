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

cfg.base_dir   = '../../../data/';   % <-- CHANGE THIS
cfg.output_dir = fullfile(pwd, 'output');

cfg.coord_file = '{hemi}.inflated.coords.txt';
cfg.coord_path = '../../';

% Task 1 (minuend in diff matrix: task1 - task2)
cfg.tasks(1).name            = 'imagery';
cfg.tasks(1).subdir          = 'imagery';
cfg.tasks(1).roi_stem        = 'nicole-final-roi';


% Task 2 (subtrahend in diff matrix)
cfg.tasks(2).name            = 'dynloc';
cfg.tasks(2).subdir          = 'dynloc';
cfg.tasks(2).roi_stem        = 'nicole-new-roi';

% Center-of-mass ROI settings
cfg.com_n_vertices = 300;    % number of closest-to-COM vertices to keep
cfg.com_output_dir = fullfile(cfg.output_dir, 'com_rois');  % where to save COM ROI files
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
            resolved_coords = strrep(cfg.coord_file, '{hemi}', hemi);

            % Build full file paths
            coords_path = fullfile(cfg.coord_path, resolved_coords);
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

%% Create center-of-mass sub-ROIs
fprintf('\nCreating center-of-mass sub-ROIs (n=%d vertices)...\n', cfg.com_n_vertices);

nSubj  = numel(cfg.subjects);
nHemis = numel(cfg.hemis);
nTasks = numel(cfg.tasks);

for s = 1:nSubj
    subj = cfg.subjects{s};

    for h = 1:nHemis
        hemi = cfg.hemis{h};

        for t = 1:nTasks
            task = cfg.tasks(t);
            fprintf('  COM ROI: %s | %s | %s\n', subj, hemi, task.name);

            coords_fname = strrep(cfg.coord_file, '{hemi}', hemi);
            coords_path  = fullfile(cfg.coord_path, coords_fname);

            roi_fname = sprintf('ref.%s-%s.1D.roi', task.roi_stem, hemi);
            roi_path  = fullfile(cfg.base_dir, subj, task.subdir, roi_fname);

            % Output goes in: <com_output_dir>/<subj>/<task.name>/
            subj_com_dir = fullfile(cfg.com_output_dir, subj, task.name);

            try
                create_com_roi(roi_path, coords_path, cfg.roi_list, ...
                               subj_com_dir, cfg.com_n_vertices);
            catch ME
                warning('COM ROI failed for %s %s %s: %s', subj, hemi, task.name, ME.message);
            end
        end
    end
end

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
