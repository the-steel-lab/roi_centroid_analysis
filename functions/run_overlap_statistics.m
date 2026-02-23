function results = run_overlap_statistics(results, cfg)
% run_overlap_statistics  Linear mixed effects model on Jaccard overlap.
%
% PURPOSE:
%   Fits a single LME with Hemisphere and Surface (ROI name) as fixed
%   effects and Subject as a random intercept.  Model formula:
%       Jaccard ~ Hemisphere * Surface + (1|Subjects)
%
% INPUTS:
%   results : struct  output from compute_overlap; must contain
%             results.roi(ri).overlap.(hemi).jaccard vectors.
%   cfg     : struct  configuration struct from run_roi_analysis, with
%                     fields: subjects, hemis, roi_names.
%
% OUTPUTS:
%   results : input struct with new top-level fields:
%     .overlap_lme            - fitlme model object
%     .overlap_anova          - anova table from the LME
%     .overlap_ttest_hemi     - struct: lh vs rh t-test (tstat, df, p, cohens_d)
%     .overlap_ttest_surface  - struct array: pairwise surface t-tests

vars  = {'Subjects', 'Hemisphere', 'Surface', 'Jaccard'};
nSubj = numel(cfg.subjects);
nHemi = numel(cfg.hemis);
nROI  = numel(cfg.roi_names);
nRows = nSubj * nHemi * nROI;

data_cell = cell(nRows, 4);

c = 0;
for roi = 1:nROI
    for hi = 1:nHemi
        hemi = cfg.hemis{hi};
        for si = 1:nSubj
            c = c + 1;
            data_cell{c,1} = cfg.subjects{si};
            data_cell{c,2} = hemi;
            data_cell{c,3} = cfg.roi_names{roi};
            data_cell{c,4} = results.roi(roi).overlap.(hemi).jaccard(si);
        end
    end
end

T = cell2table(data_cell, 'VariableNames', vars);

%% Fit LME: fixed effects of Hemisphere and Surface, random subject intercept
lmeModel    = fitlme(T, 'Jaccard ~ Hemisphere * Surface + (1|Subjects)');
anova_stats = anova(lmeModel);

fprintf('\n=== Jaccard Overlap LME (Hemisphere * Surface) ===\n');
disp(anova_stats);

results.overlap_lme   = lmeModel;
results.overlap_anova = anova_stats;

%% Follow-up pairwise t-tests: Hemisphere (lh vs rh)
fprintf('\n--- Follow-up: Hemisphere ---\n');
meanT_hemi = groupsummary(T, {'Subjects','Hemisphere'}, 'mean', 'Jaccard');
meanT_hemi = sortrows(meanT_hemi, {'Hemisphere', 'Subjects'});

lh_vals = meanT_hemi(strcmp(meanT_hemi.Hemisphere, cfg.hemis{1}), :);
rh_vals = meanT_hemi(strcmp(meanT_hemi.Hemisphere, cfg.hemis{2}), :);

[~, p, ~, stats] = ttest(lh_vals.mean_Jaccard, rh_vals.mean_Jaccard);
diff = lh_vals.mean_Jaccard - rh_vals.mean_Jaccard;
d    = mean(diff, 'omitnan') / std(diff, 0, 'omitnan');
fprintf('%s vs %s:\tt(%d) = %.3f, p = %.3f, d = %.3f\n', ...
    cfg.hemis{1}, cfg.hemis{2}, stats.df, stats.tstat, p, d);

results.overlap_ttest_hemi = struct( ...
    'hemi1', cfg.hemis{1}, 'hemi2', cfg.hemis{2}, ...
    'tstat', stats.tstat, 'df', stats.df, 'p', p, 'cohens_d', d);

%% Follow-up pairwise t-tests: Surface
fprintf('\n--- Follow-up: Surface (pairwise) ---\n');
meanT_surf = groupsummary(T, {'Subjects','Surface'}, 'mean', 'Jaccard');
meanT_surf = sortrows(meanT_surf, {'Surface', 'Subjects'});

pair_idx = 0;
for i = 1:nROI
    for j = i+1:nROI
        pair_idx = pair_idx + 1;
        surf_i = cfg.roi_names{i};
        surf_j = cfg.roi_names{j};

        vals_i = meanT_surf(strcmp(meanT_surf.Surface, surf_i), :);
        vals_j = meanT_surf(strcmp(meanT_surf.Surface, surf_j), :);

        [~, p, ~, stats] = ttest(vals_i.mean_Jaccard, vals_j.mean_Jaccard);
        diff = vals_i.mean_Jaccard - vals_j.mean_Jaccard;
        d    = mean(diff, 'omitnan') / std(diff, 0, 'omitnan');
        fprintf('%s vs %s:\tt(%d) = %.3f, p = %.3f, d = %.3f\n', ...
            surf_i, surf_j, stats.df, stats.tstat, p, d);

        results.overlap_ttest_surface(pair_idx) = struct( ...
            'surf1', surf_i, 'surf2', surf_j, ...
            'tstat', stats.tstat, 'df', stats.df, 'p', p, 'cohens_d', d);
    end
end

end
