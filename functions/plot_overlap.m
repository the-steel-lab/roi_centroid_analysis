function plot_overlap(results, cfg)
% plot_overlap  Bar plots of Jaccard overlap between tasks per hemisphere,
%               with connected individual-subject lines across surfaces.
%
% PURPOSE:
%   Produces one figure with one subplot per hemisphere.  Each subplot
%   shows group-mean bars for each ROI (surface) with grey lines connecting
%   each subject's values across surfaces, and individual subject dots
%   overlaid.  Style matches plot_results.m.
%
% INPUTS:
%   results : struct  output from compute_overlap; must contain
%             results.roi(ri).overlap.(hemi).jaccard vectors.
%   cfg     : struct  configuration struct from run_roi_analysis, with
%                     fields: output_dir, hemis, roi_names, tasks.
%
% OUTPUTS:
%   (none returned)  Files saved to:
%     <cfg.output_dir>/figures_overlap/overlap_by_surface.png
%     <cfg.output_dir>/figures_overlap/overlap_by_surface.pdf

%% -----------------------------------------------------------------------
%  Named display constants  (edit here to restyle figures globally)
%% -----------------------------------------------------------------------
COLOR_LH_BAR  = [0.20 0.60 1.00];   % blue-ish (match plot_results.m)
COLOR_RH_BAR  = [1.00 0.50 0.00];   % orange   (match plot_results.m)
COLOR_LINE    = [0.00 0.00 0.00];   % black connecting lines
COLOR_DOT     = [0.60 0.60 0.60];   % grey individual dots
LINE_ALPHA    = 0.50;
LINE_WIDTH    = 0.8;
MARKER_SIZE   = 40;                 % scatter dot size (points^2)
BAR_ALPHA     = 0.75;
DOT_ALPHA     = 0.8;

FIG_WIDTH     = 800;
FIG_HEIGHT    = 380;
%% -----------------------------------------------------------------------

nROI  = numel(cfg.roi_names);
nHemi = numel(cfg.hemis);
nSubj = numel(cfg.subjects);

bar_colors = [COLOR_LH_BAR; COLOR_RH_BAR];

%% Ensure output directory exists
dir_overlap = fullfile(cfg.output_dir, 'figures_overlap');
if ~exist(dir_overlap, 'dir'), mkdir(dir_overlap); end

fig = figure('Color', 'w', 'Visible', 'off', ...
    'Position', [100 100 FIG_WIDTH FIG_HEIGHT]);

tl = tiledlayout(fig, 1, nHemi, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Jaccard Overlap: %s vs. %s', ...
    results.task_names{1}, results.task_names{2}), 'FontSize', 11);

for hi = 1:nHemi
    hemi = cfg.hemis{hi};
    ax   = nexttile(tl);

    % Gather jaccard values: [nSubj x nROI]
    jac = NaN(nSubj, nROI);
    for roi = 1:nROI
        jac(:, roi) = results.roi(roi).overlap.(hemi).jaccard;
    end

    % Exclude subjects with no valid data (all NaN or all zero) for this hemisphere
    valid_subj = ~all(isnan(jac) | jac == 0, 2);
    jac = jac(valid_subj, :);

    grp_mean  = nanmean(jac, 1);   % 1 x nROI
    bar_color = bar_colors(hi, :);

    hold(ax, 'on');

    % Group-mean bars (one per ROI)
    for roi = 1:nROI
        bar(ax, roi, grp_mean(roi), ...
            'FaceColor', bar_color, ...
            'EdgeColor', 'none', ...
            'FaceAlpha', BAR_ALPHA);
    end

    % Connected lines: one per subject across all ROIs
    for si = 1:size(jac,1)
        y_vals = jac(si, :);   % 1 x nROI
        x_vals = 1:nROI;
        % Only draw segments between adjacent non-NaN points
        for roi = 1:nROI-1
            if ~isnan(y_vals(roi)) && ~isnan(y_vals(roi+1))
                h = plot(ax, [x_vals(roi), x_vals(roi+1)], ...
                             [y_vals(roi),  y_vals(roi+1)], '-', ...
                    'Color', COLOR_LINE, 'LineWidth', LINE_WIDTH);
                h.Color(4) = LINE_ALPHA;
            end
        end
    end

    % Individual subject dots (one per ROI)
    for roi = 1:nROI
        vals  = jac(:, roi);
        valid = ~isnan(vals);
        if any(valid)
            scatter(ax, roi * ones(sum(valid), 1), vals(valid), ...
                MARKER_SIZE, COLOR_DOT, 'filled', ...
                'MarkerFaceAlpha', DOT_ALPHA);
        end
    end

    hold(ax, 'off');

    % Axis formatting
    xlim(ax, [0.5, nROI + 0.5]);
    ylim(ax, [0, 1]);
    set(ax, 'XTick', 1:nROI, 'XTickLabel', cfg.roi_names);
    ylabel(ax, 'Jaccard Index');
    title(ax, upper(hemi));
    box(ax, 'off');
end

%% Save PNG and PDF
save_path_png = fullfile(dir_overlap, sprintf('overlap_by_surface_%s.png', cfg.study));
save_path_pdf = fullfile(dir_overlap, sprintf('overlap_by_surface_%s.pdf', cfg.study));
saveas(fig, save_path_png);
saveas(fig, save_path_pdf);
close(fig);
fprintf('  Saved: %s\n', save_path_png);
fprintf('  Saved: %s\n', save_path_pdf);

%% Averaged figure: Jaccard — LH and RH averaged per subject
% For each subject and ROI, take the nanmean of the LH and RH Jaccard
% values.  One hemisphere contributes to the mean even if the other is NaN.
if nHemi == 2
    jac_lh = NaN(nSubj, nROI);
    jac_rh = NaN(nSubj, nROI);
    for roi = 1:nROI
        jac_lh(:, roi) = results.roi(roi).overlap.(cfg.hemis{1}).jaccard;
        jac_rh(:, roi) = results.roi(roi).overlap.(cfg.hemis{2}).jaccard;
    end
    jac_avg = nanmean(cat(3, jac_lh, jac_rh), 3);   % [nSubj x nROI]

    % Exclude subjects with no valid data across all ROIs
    valid_subj_avg = ~all(isnan(jac_avg) | jac_avg == 0, 2);
    jac_avg = jac_avg(valid_subj_avg, :);

    if ~isempty(jac_avg)
        grp_mean_avg = nanmean(jac_avg, 1);   % 1 x nROI

        fig_avg = figure('Color', 'w', 'Visible', 'off', ...
            'Position', [100 100 round(FIG_WIDTH/2) FIG_HEIGHT]);
        ax_avg = axes(fig_avg); %#ok<LAXES>
        hold(ax_avg, 'on');

        % Group-mean bars
        for roi = 1:nROI
            bar(ax_avg, roi, grp_mean_avg(roi), ...
                'FaceColor', [0.40 0.55 0.70], ...
                'EdgeColor', 'none', ...
                'FaceAlpha', BAR_ALPHA);
        end

        % Connected lines per subject
        for si = 1:size(jac_avg, 1)
            y_vals = jac_avg(si, :);
            for roi = 1:nROI-1
                if ~isnan(y_vals(roi)) && ~isnan(y_vals(roi+1))
                    h = plot(ax_avg, [roi, roi+1], [y_vals(roi), y_vals(roi+1)], '-', ...
                             'Color', COLOR_LINE, 'LineWidth', LINE_WIDTH);
                    h.Color(4) = LINE_ALPHA;
                end
            end
        end

        % Individual subject dots
        for roi = 1:nROI
            vals  = jac_avg(:, roi);
            valid = ~isnan(vals);
            if any(valid)
                scatter(ax_avg, roi * ones(sum(valid), 1), vals(valid), ...
                    MARKER_SIZE, COLOR_DOT, 'filled', ...
                    'MarkerFaceAlpha', DOT_ALPHA);
            end
        end

        hold(ax_avg, 'off');
        xlim(ax_avg, [0.5, nROI + 0.5]);
        ylim(ax_avg, [0, 1]);
        set(ax_avg, 'XTick', 1:nROI, 'XTickLabel', cfg.roi_names);
        ylabel(ax_avg, 'Jaccard Index');
        title(ax_avg, sprintf('Jaccard Overlap LH+RH avg: %s vs. %s', ...
              results.task_names{1}, results.task_names{2}));
        box(ax_avg, 'off');

        save_path_avg_png = fullfile(dir_overlap, sprintf('overlap_by_surface_avg_%s.png', cfg.study));
        save_path_avg_pdf = fullfile(dir_overlap, sprintf('overlap_by_surface_avg_%s.pdf', cfg.study));
        saveas(fig_avg, save_path_avg_png);
        saveas(fig_avg, save_path_avg_pdf);
        close(fig_avg);
        fprintf('  Saved: %s\n', save_path_avg_png);
        fprintf('  Saved: %s\n', save_path_avg_pdf);
    end
end

end
