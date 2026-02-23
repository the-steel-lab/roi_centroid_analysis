function results = run_shift_statistics(results,cfg)
%%
%%
vars = {'Subjects','Hemis','Task','Shift'};
roi_cell = cell(size(cfg.roi_names));


%% populate a cell array and turn it into a table
for roi = 1:numel(cfg.roi_names)
    roi_cell{roi} = cell(numel(cfg.subjects)*numel(cfg.hemis),3);
    c = 0 ;% counter
    for hi = 1:numel(cfg.hemis)
        hemi = cfg.hemis{hi};

        for ti = 1:numel(cfg.tasks)
            task = cfg.tasks(ti).name;
        
            for si = 1:numel(cfg.subjects)
                c = c+1;
                roi_cell{roi}{c,1} = cfg.subjects{si};
                roi_cell{roi}{c,2} = hemi;
                roi_cell{roi}{c,3} = task;
                roi_cell{roi}{c,4} = results.roi(roi).centroid.(task)(si,2,hi); % get the y axis value
            end

        end
    end
end

for roi = 1:4
    roi_cell{roi} = cell2table(roi_cell{roi},'VariableNames',vars);
end

%%
% run a linear mixed effects model with task and hemisphere as a fixed effect and
% subject as a random effect

for roi = 1:4
    lmeModel = fitlme(roi_cell{roi}, 'Shift ~ Task * Hemis + (1|Subjects)');
    anova_stats = anova(lmeModel);
    % fprintf anova output
    fprintf('ANOVA results for %s:\n', cfg.roi_names{roi});
    disp(anova_stats);
    %%
    meanT = groupsummary(roi_cell{roi},{'Subjects','Task'},'mean','Shift');
    meanT = sortrows(meanT, {'Task', 'Subjects'});

    % Split by task
    perception = meanT(strcmp(meanT.Task, cfg.tasks(1).name), :);
    memory     = meanT(strcmp(meanT.Task, cfg.tasks(2).name),     :);
    
    % Paired t-test (one per ROI, so no correction needed here)
    [~, tresult.p, tresult.ci, tresult.stats] = ttest(perception.mean_Shift, memory.mean_Shift);
    
    diff        = perception.mean_Shift - memory.mean_Shift;
    tresult.cohens_d    = mean(diff,'omitnan') / std(diff,0,'omitnan');

    
    fprintf('%s:\tt(%d) = %.3f, p = %.3f, d = %.3f\n', ...
        cfg.roi_names{roi},...
        tresult.stats.df, ...
        tresult.stats.tstat, ...
        tresult.p, ...
        tresult.cohens_d)
    
    results.roi(roi).lmeModel = lmeModel;
    results.roi(roi).anova_stats = anova_stats;
    results.roi(roi).tresult = tresult;

    % ttest for hemisphere effects

    meanT_hemi = groupsummary(roi_cell{roi}, {'Subjects','Hemis'}, 'mean', 'Shift');
    meanT_hemi = sortrows(meanT_hemi, {'Hemis', 'Subjects'});
    
    lh_vals = meanT_hemi(strcmp(meanT_hemi.Hemis, cfg.hemis{1}), :);
    rh_vals = meanT_hemi(strcmp(meanT_hemi.Hemis, cfg.hemis{2}), :);
    
    [~, p, ~, stats] = ttest(lh_vals.mean_Shift, rh_vals.mean_Shift);
    diff = lh_vals.mean_Shift - rh_vals.mean_Shift;
    d    = mean(diff, 'omitnan') / std(diff, 0, 'omitnan');
    fprintf('%s vs %s:\tt(%d) = %.3f, p = %.3f, d = %.3f\n\n\n', ...
        cfg.hemis{1}, cfg.hemis{2}, stats.df, stats.tstat, p, d);
    
    results.roi(roi).t_hemiresult = struct( ...
        'hemi1', cfg.hemis{1}, 'hemi2', cfg.hemis{2}, ...
        'tstat', stats.tstat, 'df', stats.df, 'p', p, 'cohens_d', d);
end

%% run Rayleigh's test of uniformity on shift angle

fprintf('++ Rayleigh test\n')
for roi = 1:4
    shiftAngles = results.roi(roi).diff_theta; % Assuming first task for shift angles
    shiftAngles = mean(shiftAngles,2,'omitnan');
    shiftAngles = shiftAngles(~isnan(shiftAngles)); % Remove NaN values

    [pRayleigh, zRayleigh] = circ_rtest(shiftAngles); % Perform Rayleigh's test
    results.roi(roi).rayleighTest.p = pRayleigh;
    results.roi(roi).rayleighTest.z = zRayleigh;
    fprintf('%s:\tRayleigh test z: %.3f, p = %.3f\n',cfg.roi_names{roi},zRayleigh,pRayleigh);
end