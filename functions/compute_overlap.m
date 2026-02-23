function results = compute_overlap(results, subjectData, cfg)
% compute_overlap  Compute vertex-level Jaccard overlap between two tasks
%                  for each ROI, hemisphere, and subject.
%
% PURPOSE:
%   For each ROI x hemisphere x subject combination, retrieves the sets of
%   vertex indices assigned to that ROI under task 1 and task 2, then
%   computes the intersection size, union size, and Jaccard index
%   (intersection / union).
%
% INPUTS:
%   results     : struct  output from build_group_matrices; overlap fields
%                         are ADDED to this struct (existing fields preserved).
%   subjectData : struct  subjectData.(hemi).(subj).(taskname) = S
%                         where S is the output of load_roi_data.
%   cfg         : struct  configuration struct from run_roi_analysis, with
%                         fields: subjects, hemis, roi_list, tasks.
%
% OUTPUTS:
%   results : the input results struct with the following new fields added
%             for each ROI index ri and hemisphere hemi:
%     .roi(ri).overlap.(hemi).n_task1(s)   number of vertices in task1 for subject s
%     .roi(ri).overlap.(hemi).n_task2(s)   number of vertices in task2 for subject s
%     .roi(ri).overlap.(hemi).n_shared(s)  size of vertex-index intersection
%     .roi(ri).overlap.(hemi).jaccard(s)   n_shared / union  (NaN if union==0 or data missing)
%
% NOTES ON MISSING DATA:
%   - If either task's data has .missing==true, all four overlap fields for
%     that subject remain NaN.
%   - Vertex indices are the 0-based integers stored in S.vertices{r}.
%   - If the union of the two vertex sets is empty (size zero), jaccard is
%     set to NaN rather than 0/0.

subjects   = cfg.subjects;
hemis      = cfg.hemis;
roi_list   = cfg.roi_list;
task_names = {cfg.tasks.name};

nSubj = numel(subjects);
nHemi = numel(hemis);
nROI  = numel(roi_list);

t1name = task_names{1};
t2name = task_names{2};

for ri = 1:nROI
    r = roi_list(ri);

    for hi = 1:nHemi
        hemi = hemis{hi};

        % Preallocate overlap arrays for this ROI x hemi
        n_task1  = NaN(nSubj, 1);
        n_task2  = NaN(nSubj, 1);
        n_shared = NaN(nSubj, 1);
        jaccard  = NaN(nSubj, 1);

        for si = 1:nSubj
            subj = subjects{si};

            % Retrieve task1 and task2 structs for this subject/hemi
            has_t1 = isfield(subjectData, hemi) && ...
                     isfield(subjectData.(hemi), subj) && ...
                     isfield(subjectData.(hemi).(subj), t1name);
            has_t2 = isfield(subjectData, hemi) && ...
                     isfield(subjectData.(hemi), subj) && ...
                     isfield(subjectData.(hemi).(subj), t2name);

            if ~has_t1 || ~has_t2
                continue;   % leave as NaN
            end

            S1 = subjectData.(hemi).(subj).(t1name);
            S2 = subjectData.(hemi).(subj).(t2name);

            % Skip if either file was flagged as missing
            if S1.missing || S2.missing
                continue;
            end

            % Retrieve vertex index vectors (0-based integers)
            % Guard against ROI number exceeding preallocated cell length
            vtx1 = [];
            vtx2 = [];

            if r <= numel(S1.vertices) && ~isempty(S1.vertices{r})
                vtx1 = S1.vertices{r}(:);
            end
            if r <= numel(S2.vertices) && ~isempty(S2.vertices{r})
                vtx2 = S2.vertices{r}(:);
            end

            % Compute set statistics
            n1 = numel(vtx1);
            n2 = numel(vtx2);

            n_task1(si) = n1;
            n_task2(si) = n2;

            if n1 == 0 || n2 == 0
                % At least one task ROI is missing — overlap undefined
                n_shared(si) = NaN;
                jaccard(si)  = NaN;
            else
                shared       = numel(intersect(vtx1, vtx2));
                union_count  = numel(union(vtx1, vtx2));
                n_shared(si) = shared;
                if union_count == 0
                    jaccard(si) = NaN;
                else
                    jaccard(si) = shared / union_count;
                end
            end

        end % subjects

        % Store in results struct
        results.roi(ri).overlap.(hemi).n_task1  = n_task1;
        results.roi(ri).overlap.(hemi).n_task2  = n_task2;
        results.roi(ri).overlap.(hemi).n_shared = n_shared;
        results.roi(ri).overlap.(hemi).jaccard  = jaccard;

    end % hemis
end % ROIs

end
