%% analyses_figure_1 
% behavioural analyses of the paper (all 19 participants as in Morillon & Baillet, 2017):
%   Fig. 1b  accuracy (fraction of optimal choices w.r.t. the mean of the log2 frequencies
%            of the 8 targets), tracking > listen, and listen vs tracking correlation
%   Fig. 1c  element weights (probit regression of choice on the 16 tones, targets
%            without the first and distractors without the last): tracking > listen for
%            targets and distractors, condition x sound type ANOVA, target > distractor
clearvars
close all
clc

saveornot = false;

paths = config_paths();

% defaults
load(paths.table,'data')
condname = {'_tracking', '_listen'};
participants = unique(data.name);
ndata = numel(unique(participants));
f_ref = 440;
ntone = 16;

figpath = paths.fig_dir;
rgb = lines;

cfg_fig = [];
cfg_fig.saveornot = saveornot;
cfg_fig.figpath = figpath ;

%% MAIN Fig. 1b: Participants' overall accuracy w.r.t estimated mean of targets (log2(f))
% are participants better in Tracking than Listen?

pcor_opt     = nan(ndata,2);
for idata = 1:ndata
    fprintf('Subject %2d/%2d...\n',idata,ndata);
    for icond = 1:2  % tracking•listen
        ifilt = data.subject == idata & data.("tap/lis") == icond & data.("tar/dis") == 1;
        
        % data selection
        pitch = data.pitch(ifilt);
        x = reshape(pitch, ntone/2,[]);
        xavg = mean(x); % estimated melody pitch

        resp = data.response(ifilt);
        resp = reshape(resp, ntone/2,[]);
        resp = mean(resp,1);
        
        pcor_opt(idata,icond) = mean(sign(xavg-log2(f_ref))==resp);
    end
end
% plot
cfg = cfg_fig;
cfg.figname = 'fig1b_accuracy_listen_tracking';
cfg.ylim = [0.5 1];
cfg.ttest = true;
cfg.tail = 'left';   % tracking > listen
cfg.x = pcor_opt(:,[2 1]);
cfg.plotx = true;
cfg.rgb = flipud(rgb(1:2,:));
cfg.ylabel = 'accuracy';
cfg.xlabel = 'condition';
cfg.xticklabel = {'listen' 'tracking'};
helper_plot_overall_bars(cfg)

fprintf('Participants accuracy (w.r.t. estimated mean) differ between Tracking and Listen?\n')
[H,pval,~,stats] = ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
fprintf('\tone-sided ttest TAP>LIS:        H = %d; p = %4.4f; t = %4.4f\n',H,pval,stats.tstat)

cfg = cfg_fig;
cfg.figname = 'fig1b_accuracy_correlation';
cfg.xavg = pcor_opt(:,2);
cfg.yavg = pcor_opt(:,1);
cfg.xlabel = 'listen';
cfg.ylabel = 'tracking';
cfg.xlim = [0.5 1]; cfg.ylim = [0.5 1];
helper_plot_corr(cfg)

%% MAIN Fig. 1c: Weight of tone on response depending on position in sequence
breg = nan(ndata,2,ntone);
for idata = 1:ndata
    fprintf('Subject %2d/%2d...\n',idata,ndata);
    for icond = 1:2  % tracking•listen
        ifilt = data.subject == idata & data.("tap/lis") == icond;
        % data selection
        dfq = data.dfq(ifilt); % distance to reference dfq = log2(fq/f_ref);
        x = reshape(dfq, ntone,[]);
        resp = data.response(ifilt);
        resp = reshape(resp, ntone,[]);
        resp = mean(resp,1);
        
        B = glmfit(x', resp'>0, 'binomial','link','probit');
        breg(idata,icond,:) = B(2:end); % remove intercept
    end
end


% bar plot without first target and last distractor 
% (see Morillon & Baillet 2017)
% TAR
x1 = squeeze(mean(breg(:,1,3:2:end),3));
x2 = squeeze(mean(breg(:,2,3:2:end),3));
cfg = cfg_fig;
cfg.figname = 'fig1c_integration_weight_target';
cfg.ylim = [0 2.5];
cfg.plotx = true;
cfg.ttest = true;
cfg.tail = 'left'; 
cfg.x = [x2 x1];
cfg.rgb = flipud([rgb(1,:);rgb(2,:)]);
cfg.ylabel = 'element weight';
cfg.xlabel = 'target';
cfg.xticklabel = {'listen','tracking'};
helper_plot_overall_bars(cfg)

[H,pval,~,stats] = ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
fprintf('\tone-sided ttest TAP>LIS:        H = %d; p = %4.4f; t = %4.4f\n',H,pval,stats.tstat)

% DIS
x1 = squeeze(mean(breg(:,1,2:2:end-1),3));
x2 = squeeze(mean(breg(:,2,2:2:end-1),3));
cfg = cfg_fig;
cfg.figname = 'fig1c_integration_weight_distractor';
cfg.ylim = [0 2.5];
cfg.plotx = true;
cfg.ttest = true;
cfg.tail = 'left'; 
cfg.x = [x2 x1];
cfg.rgb = flipud((1+[rgb(1,:);rgb(2,:)])/2);
cfg.ylabel = 'element weight';
cfg.xlabel = 'distractor';
cfg.xticklabel = {'listen','tracking'};
helper_plot_overall_bars(cfg)

[H,pval,~,stats] = ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
fprintf('\tone-sided ttest TAP>LIS:        H = %d; p = %4.4f; t = %4.4f\n',H,pval,stats.tstat)

% reshape regressor coefficients for anova
b_TAR = mean(breg(:,:,3:2:end),3);   % targets without the first
b_DIS = mean(breg(:,:,2:2:end-1),3); % distractors without the last
b = cat(3,b_TAR,b_DIS);
anova_2x2_ttest(b,{'condition','soundtype'},'element weight (response), targets without the first, distractors without the last');

% target > distractor weight in each condition (one-tailed, stars of Fig. 1c)
fprintf('element weight, target > distractor:\n')
for icond = 1:2  % tracking•listen
    [H,pval,~,stats] = ttest(b_TAR(:,icond),b_DIS(:,icond),'tail','right');
    fprintf('\t%-9s one-sided ttest:        H = %d; p = %4.4f; t = %4.4f\n',condname{icond}(2:end),H,pval,stats.tstat)
end
