function results = build_group_matrices(subjectData, cfg)
% build_group_matrices  Assemble per-ROI group centroid matrices across
%                       subjects and hemispheres.
%
% PURPOSE:
%   For each ROI in cfg.roi_list, collects centroid coordinates from every
%   subject/hemisphere/task loaded into subjectData, stacks them into
%   [nSubjects x 3 x nHemis] arrays, and computes a difference matrix
%   (task1 centroid - task2 centroid).
%
% INPUTS:
%   subjectData : struct  subjectData.(hemi).(subj).(taskname)  = S
%                         where S is the output of load_roi_data.
%   cfg         : struct  configuration struct from run_roi_analysis, with
%                         fields: subjects, hemis, roi_list, tasks.
%
% OUTPUTS:
%   results : struct with fields:
%     .subjects            copy of cfg.subjects
%     .hemis               copy of cfg.hemis
%     .roi_list            copy of cfg.roi_list
%     .task_names          {cfg.tasks.name}
%     .roi(r).roi_num      the actual ROI number
%     .roi(r).centroid.(taskname)   [nSubj x 3 x nHemi]  NaN where missing
%     .roi(r).diff_matrix           [nSubj x 3 x nHemi]  task1 - task2
%
% NOTES ON MISSING DATA:
%   Any subject/hemi/task combination for which the centroid cannot be
%   retrieved (missing file, ROI not found, or load error) is left as NaN
%   in the output matrices. Downstream plotting functions handle NaN rows.

subjects   = cfg.subjects;
hemis      = cfg.hemis;
roi_list   = cfg.roi_list;
task_names = {cfg.tasks.name};

nSubj  = numel(subjects);
nHemi  = numel(hemis);
nROI   = numel(roi_list);
nTask  = numel(task_names);

%% Initialise output struct
results.subjects   = subjects;
results.hemis      = hemis;
results.roi_list   = roi_list;
results.task_names = task_names;

for ri = 1:nROI
    r = roi_list(ri);   % actual ROI number
    results.roi(ri).roi_num = r;

    % Preallocate centroid matrices: [nSubj x 3 x nHemi], filled with NaN
    for ti = 1:nTask
        tname = task_names{ti};
        results.roi(ri).centroid.(tname) = NaN(nSubj, 3, nHemi);
    end

    %% Fill centroid matrices
    for hi = 1:nHemi
        hemi = hemis{hi};

        for si = 1:nSubj
            subj = subjects{si};

            for ti = 1:nTask
                tname = task_names{ti};

                % Check that this subject/hemi/task entry exists in subjectData
                if ~isfield(subjectData, hemi) || ...
                   ~isfield(subjectData.(hemi), subj) || ...
                   ~isfield(subjectData.(hemi).(subj), tname)
                    continue;   % leave as NaN
                end

                S = subjectData.(hemi).(subj).(tname);

                % Skip if data was flagged missing
                if S.missing
                    continue;
                end

                % Check the ROI number is within the preallocated cell array
                % and has a non-empty centroid
                if r > numel(S.centroid) || isempty(S.centroid{r})
                    continue;
                end

                cent = S.centroid{r};

                % Validate: must be 1x3 numeric, no NaN
                if ~isnumeric(cent) || numel(cent) ~= 3 || any(isnan(cent))
                    continue;
                end

                results.roi(ri).centroid.(tname)(si, :, hi) = cent(:)';
            end % tasks
        end % subjects
    end % hemis

    %% Compute difference matrix: task1 - task2
    t1name = task_names{1};
    t2name = task_names{2};
    results.roi(ri).diff_matrix = ...
        results.roi(ri).centroid.(t1name) - results.roi(ri).centroid.(t2name);

end % ROIs

end
