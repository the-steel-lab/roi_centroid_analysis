function plot_results(results, cfg)
% plot_results  Generate and save centroid-shift bar plots and Y-Z polar
%               plots for all ROIs.
%
% PURPOSE:
%   Produces two figure types for each ROI in results.roi_list:
%     (A) Centroid shift bar plots — group-mean bars for X/Y/Z axes with
%         individual subject dots overlaid, one subplot per hemisphere.
%     (B) Polar plots in the Y-Z plane — one subplot per hemisphere, with
%         each subject drawn as a radial line + dot at (Y_diff, Z_diff).
%   Figures are saved as PNG files into subdirectories of cfg.output_dir.
%   Figures are not displayed interactively (Visible='off' during save).
%
% INPUTS:
%   results : struct  output from compute_overlap (and build_group_matrices)
%   cfg     : struct  configuration struct from run_roi_analysis, with
%                     fields: output_dir, tasks, hemis.
%
% OUTPUTS:
%   (none returned)  Files saved to:
%     <cfg.output_dir>/figures_centroid_shift/ROI<N>_centroid_shift.png
%     <cfg.output_dir>/figures_polar/ROI<N>_polar_YZ.png
%
% NOTES ON MISSING DATA:
%   - NaN subjects are omitted from individual-dot overlays.
%   - Group mean bars are computed with nanmean; if all subjects are NaN
%     for both hemispheres, the figure is skipped entirely.
%   - Polar plots skip hemispheres with no valid subjects.

%% -----------------------------------------------------------------------
%  Named display constants  (edit here to restyle figures globally)
%% -----------------------------------------------------------------------
% Bar colors per hemisphere
COLOR_LH_BAR       = [0.20 0.60 1.00];   % blue-ish
COLOR_RH_BAR       = [1.00 0.50 0.00];   % orange
COLOR_AVG_BAR      = [0.40 0.55 0.70];   % slate blue (LH+RH averaged)

% Individual dot colors per axis (X, Y, Z)
COLOR_DOT_X        = [0.60 0.60 0.60];
COLOR_DOT_Y        = [0.60 0.60 0.60];
COLOR_DOT_Z        = [0.60 0.60 0.60];

% Polar line/dot colors per hemisphere
COLOR_LH_POLAR     = [0.20 0.60 1.00];
COLOR_RH_POLAR     = [1.00 0.50 0.00];

% Marker and line properties
MARKER_SIZE_DOT    = 40;    % scatter dot size (points^2)
MARKER_SIZE_POLAR  = 8;     % polar endpoint dot size (points)
LINE_WIDTH_POLAR   = 1.2;   % radial line width
LINE_WIDTH_ZERO    = 1.0;   % y=0 reference line width

% Figure dimensions (pixels)
FIG_WIDTH_BAR      = 960;
FIG_HEIGHT_BAR     = 400;
FIG_WIDTH_POLAR    = 800;
FIG_HEIGHT_POLAR   = 420;

% Axis tick labels for bar plot
AXIS_LABELS        = {'X', 'Y', 'Z'};
%% -----------------------------------------------------------------------

t1name = results.task_names{1};
t2name = results.task_names{2};
hemis  = results.hemis;
nHemi  = numel(hemis);
nROI   = numel(results.roi_list);

%% Ensure output subdirectories exist
dir_bar   = fullfile(cfg.output_dir, 'figures_centroid_shift');
dir_polar = fullfile(cfg.output_dir, 'figures_polar');
if ~exist(dir_bar,   'dir'), mkdir(dir_bar);   end
if ~exist(dir_polar, 'dir'), mkdir(dir_polar); end

%% -----------------------------------------------------------------------
%  Loop over ROIs
%% -----------------------------------------------------------------------
for ri = 1:nROI
    r    = results.roi(ri).roi_num;
    diff = results.roi(ri).diff_matrix;   % [nSubj x 3 x nHemi]
    diff_theta = results.roi(ri).diff_theta ; %nSubj x nHemi
    diff_rho = results.roi(ri).diff_rho ; %nSubj x nHemi

    % ------------------------------------------------------------------
    % Figure A: Centroid shift bar plots
    % ------------------------------------------------------------------
    % Check whether any valid (non-NaN) data exists across all hemis
    all_nan_bar = true;
    for hi = 1:nHemi
        slice = diff(:, :, hi);
        if any(~isnan(slice(:)))
            all_nan_bar = false;
            break;
        end
    end

    if ~all_nan_bar
        fig_bar = figure('Color', 'w', 'Visible','off',...
            'Position', [100 100 FIG_WIDTH_BAR FIG_HEIGHT_BAR]);

        for hi = 1:nHemi
            hemi      = hemis{hi};
            ax        = subplot(1, nHemi, hi);
            diff_hemi = diff(:, :, hi);   % [nSubj x 3]

            % Group means (ignore NaN subjects)
            grp_mean = nanmean(diff_hemi, 1);   % 1x3

            % Choose bar color
            if strcmpi(hemi, 'lh')
                bar_color = COLOR_LH_BAR;
            else
                bar_color = COLOR_RH_BAR;
            end

            % Bar chart of mean per axis
            bh = bar(ax, 1:3, grp_mean, 'FaceColor', bar_color, ...
                     'EdgeColor', 'none', 'FaceAlpha', 0.75);

            hold(ax, 'on');

            % Overlay individual subject dots, per axis
            dot_colors = [COLOR_DOT_X; COLOR_DOT_Y; COLOR_DOT_Z];
            for ax_idx = 1:3
                col_data = diff_hemi(:, ax_idx);
                valid    = ~isnan(col_data);
                if any(valid)
                    x_jitter = ax_idx + 0.0 * (rand(sum(valid),1) - 0.5);
                    scatter(ax, x_jitter, col_data(valid), MARKER_SIZE_DOT, ...
                            dot_colors(ax_idx,:), 'filled', ...
                            'MarkerFaceAlpha', 0.7);
                end
            end

            % Reference line at y = 0
            xlim_vals = [0.5, 3.5];
            plot(ax, xlim_vals, [0 0], 'k-', 'LineWidth', LINE_WIDTH_ZERO);

            hold(ax, 'off');

            % Axis formatting
            set(ax, 'XTick', 1:3, 'XTickLabel', AXIS_LABELS);
            xlabel(ax, 'Axis');
            ylabel(ax, sprintf('%s - %s (mm)', t1name, t2name));
            title(ax, sprintf('ROI %d - %s centroid shift (%s - %s)', ...
                              r, upper(hemi), t1name, t2name));
            xlim(ax, xlim_vals);
            box(ax, 'off');
        end

        % Save and close
        save_path_bar = fullfile(dir_bar, sprintf('ROI%d_centroid_shift_%s.png', r, cfg.study));
        saveas(fig_bar, save_path_bar);
        close(fig_bar);
        fprintf('  Saved: %s\n', save_path_bar);

        % ------------------------------------------------------------------
        % Figure A2: Centroid shift bar plot — hemispheres averaged
        % ------------------------------------------------------------------
        if nHemi == 2
            diff_lh    = diff(:, :, 1);   % [nSubj x 3]
            diff_rh    = diff(:, :, 2);   % [nSubj x 3]
            diff_rh_lm = diff_rh;
            % RH X dimension is multiplied by -1 so it reflects lateral-medial
            % displacement (matching LH orientation) before the two hemispheres
            % are averaged together.
            diff_rh_lm(:, 1) = -diff_rh(:, 1);
            diff_avg = nanmean(cat(3, diff_lh, diff_rh_lm), 3);   % [nSubj x 3]

            if any(~isnan(diff_avg(:)))
                fig_bar_avg = figure('Color', 'w', 'Visible', 'off', ...
                    'Position', [100 100 round(FIG_WIDTH_BAR/2) FIG_HEIGHT_BAR]);
                ax_avg = axes(fig_bar_avg); %#ok<LAXES>

                grp_mean_avg = nanmean(diff_avg, 1);   % 1x3
                bar(ax_avg, 1:3, grp_mean_avg, 'FaceColor', COLOR_AVG_BAR, ...
                    'EdgeColor', 'none', 'FaceAlpha', 0.75);
                hold(ax_avg, 'on');

                dot_colors_avg = [COLOR_DOT_X; COLOR_DOT_Y; COLOR_DOT_Z];
                for ax_idx = 1:3
                    col_data = diff_avg(:, ax_idx);
                    valid    = ~isnan(col_data);
                    if any(valid)
                        scatter(ax_avg, ax_idx + zeros(sum(valid),1), col_data(valid), ...
                                MARKER_SIZE_DOT, dot_colors_avg(ax_idx,:), 'filled', ...
                                'MarkerFaceAlpha', 0.7);
                    end
                end

                plot(ax_avg, [0.5, 3.5], [0 0], 'k-', 'LineWidth', LINE_WIDTH_ZERO);
                hold(ax_avg, 'off');

                set(ax_avg, 'XTick', 1:3, 'XTickLabel', {'X (lat-med)', 'Y', 'Z'});
                xlabel(ax_avg, 'Axis');
                ylabel(ax_avg, sprintf('%s - %s (mm)', t1name, t2name));
                title(ax_avg, sprintf('ROI %d - LH+RH avg centroid shift (%s - %s)', ...
                                      r, t1name, t2name));
                xlim(ax_avg, [0.5, 3.5]);
                box(ax_avg, 'off');

                save_path_bar_avg = fullfile(dir_bar, ...
                    sprintf('ROI%d_centroid_shift_avg_%s.png', r, cfg.study));
                saveas(fig_bar_avg, save_path_bar_avg);
                close(fig_bar_avg);
                fprintf('  Saved: %s\n', save_path_bar_avg);
            end
        end
    else
        fprintf('  Skipping bar plot for ROI %d (all NaN)\n', r);
    end

    % ------------------------------------------------------------------
    % Figure B: Polar plots in Y-Z plane
    % ------------------------------------------------------------------
    % Check whether any valid data exists (Y and Z columns = cols 2 and 3)
    all_nan_polar = true;
    for hi = 1:nHemi
        rho_vals = diff_rho(:, hi);
        theta_vals = diff_theta(:, hi);
        valid  = ~isnan(rho_vals) & ~isnan(theta_vals);
        if any(valid)
            all_nan_polar = false;
            break;
        end
    end

    if ~all_nan_polar
        fig_pol = figure('Color', 'w', 'Visible','off',...
            'Position', [100 100 FIG_WIDTH_POLAR FIG_HEIGHT_POLAR]);

        tl = tiledlayout(fig_pol, 1, nHemi, 'TileSpacing', 'compact', ...
                         'Padding', 'compact');
        title(tl, sprintf('ROI %d Polar (Y–Z): %s − %s', r, t1name, t2name), ...
              'FontSize', 11);

        % Compute shared radial limit across both hemispheres


        

        for hi = 1:nHemi
            hemi   = hemis{hi};
            ax_pol = polaraxes(tl);
            ax_pol.Layout.Tile = hi;
            

            valid  = ~isnan(diff_rho(:,hi)) ;

            % Choose polar color
            if strcmpi(hemi, 'lh')
                pol_color = COLOR_LH_POLAR;
            else
                pol_color = COLOR_RH_POLAR;
            end

            hold(ax_pol, 'on');

            if any(valid)
                theta_v = diff_theta(valid,hi);
                rho_v = diff_rho(valid,hi);

                if isempty(rho_vals) || max(rho_vals) == 0
                    rho_lim = 1;   % fallback
                else
                    rho_lim = max([max(rho_v) 40]);
                end

                for si = 1:numel(rho_v)
                    % Radial line from origin to subject point
                    polarplot(ax_pol, [0 theta_v(si)], [0 rho_v(si)], '-', ...
                         'Color', pol_color, 'LineWidth', LINE_WIDTH_POLAR);
                    % Dot at endpoint
                    polarplot(ax_pol, [0 theta_v(si)], [0 rho_v(si)], 'o', ...
                         'Color', pol_color, 'MarkerFaceColor', pol_color, ...
                         'MarkerSize', MARKER_SIZE_POLAR);
                end
            end

            hold(ax_pol, 'off');

            % Axis formatting
            rlim(ax_pol, [0 rho_lim]);
            rticks(floor(linspace(0,rho_lim,5)))
            thetaticks([0 45 90 135 180 225 270])
            thetaticklabels({'Ant','','Dor','','Post','','Vent'})
            title(ax_pol, sprintf('%s', upper(hemi)));
            box(ax_pol, 'off');
        end

%        Save and close
        save_path_pol = fullfile(dir_polar, sprintf('ROI%d_polar_YZ_%s.png', r, cfg.study));
        saveas(fig_pol, save_path_pol);
        save_path_pol = fullfile(dir_polar, sprintf('ROI%d_polar_YZ_%s.pdf', r, cfg.study));
        saveas(fig_pol, save_path_pol);
        close(fig_pol);
        fprintf('  Saved: %s\n', save_path_pol);

        % ------------------------------------------------------------------
        % Figure B2: Polar plot — hemispheres averaged
        % ------------------------------------------------------------------
        % Average Y and Z directly across hemispheres (no axis flip needed
        % for polar since the Y-Z plane is comparable across hemispheres).
        if nHemi == 2
            yz_lh  = diff(:, 2:3, 1);   % [nSubj x 2]  (Y, Z columns)
            yz_rh  = diff(:, 2:3, 2);   % [nSubj x 2]
            yz_avg = nanmean(cat(3, yz_lh, yz_rh), 3);   % [nSubj x 2]
            [theta_avg, rho_avg] = cart2pol(yz_avg(:,1), yz_avg(:,2));
            valid_avg = ~isnan(rho_avg);

            if any(valid_avg)
                if max(rho_avg(valid_avg)) == 0
                    rho_lim_avg = 1;
                else
                    rho_lim_avg = max([max(rho_avg(valid_avg)) 40]);
                end

                fig_pol_avg = figure('Color', 'w', 'Visible', 'off', ...
                    'Position', [100 100 round(FIG_WIDTH_POLAR/2) FIG_HEIGHT_POLAR]);
                tl_avg = tiledlayout(fig_pol_avg, 1, 1, 'TileSpacing', 'compact', ...
                                     'Padding', 'compact');
                title(tl_avg, sprintf('ROI %d Polar (Y-Z) LH+RH avg: %s - %s', ...
                      r, t1name, t2name), 'FontSize', 11);

                ax_pol_avg = polaraxes(tl_avg);
                hold(ax_pol_avg, 'on');
                for si = 1:sum(valid_avg)
                    idx = find(valid_avg);
                    polarplot(ax_pol_avg, [0 theta_avg(idx(si))], [0 rho_avg(idx(si))], '-', ...
                              'Color', COLOR_AVG_BAR, 'LineWidth', LINE_WIDTH_POLAR);
                    polarplot(ax_pol_avg, theta_avg(idx(si)), rho_avg(idx(si)), 'o', ...
                              'Color', COLOR_AVG_BAR, 'MarkerFaceColor', COLOR_AVG_BAR, ...
                              'MarkerSize', MARKER_SIZE_POLAR);
                end
                hold(ax_pol_avg, 'off');

                rlim(ax_pol_avg, [0 rho_lim_avg]);
                rticks(floor(linspace(0, rho_lim_avg, 5)));
                thetaticks([0 45 90 135 180 225 270]);
                thetaticklabels({'Ant','','Dor','','Post','','Vent'});
                title(ax_pol_avg, 'LH+RH avg');
                box(ax_pol_avg, 'off');

                save_path_pol_avg = fullfile(dir_polar, ...
                    sprintf('ROI%d_polar_YZ_avg_%s.png', r, cfg.study));
                saveas(fig_pol_avg, save_path_pol_avg);
                save_path_pol_avg = fullfile(dir_polar, ...
                    sprintf('ROI%d_polar_YZ_avg_%s.pdf', r, cfg.study));
                saveas(fig_pol_avg, save_path_pol_avg);
                close(fig_pol_avg);
                fprintf('  Saved: %s\n', save_path_pol_avg);
            end
        end
    else
        fprintf('  Skipping polar plot for ROI %d (all NaN)\n', r);
    end

end % ROIs

end
