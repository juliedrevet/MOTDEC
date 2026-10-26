%% analyses_figure_3 
% Fig. 3 and Supp. Fig. 4
% isound = 1 -> Fig. 3 (targets), isound = 2 -> Supp. Fig. 4 (distractors)
% each decoding result is loaded, or computed first if it does not exist (decode_from_sensors)
% compare conditions! not soundtypes!
% targets for main (isound = 1: pitch, evidence, update), distractors for supp
% (isound = 2: pitch and evidence, update is not defined for distractors)
% decoding without equalization (decode_from_sensors, cfg.equalize = 'none')
%   a. tracking vs listen: mean decoding t > 0, and relative enhancement
%   b. time courses tracking vs listen, and jackknifed peak amplitude and latency
%   c. effect of sound timing precision (|lte| below or above its median),
clearvars
close all
clc

isound = 1; % 1 = targets (pitch, evidence, update), 2 = distractors (pitch, evidence), always lighter colors

saveornot = false;

paths = config_paths();

rgb_lis = [179,0,0;...
    227,74,51;...
    252,141,89;...
    253,204,138;...
    254,240,217]/255;

rgb_tap = [4,90,141;...
    43,140,190;...
    120,200,203;...
    189,201,225;...
    241,238,246;...
    ]/255;

rgb_pitch = [rgb_tap(1,:);rgb_lis(1,:)];
rgb_evidence = [rgb_tap(2,:);rgb_lis(2,:)];
rgb_update = [rgb_tap(3,:);rgb_lis(3,:)];

flowpass = 8;
nsplit = 10; % decoding averaged over nsplit random splits of the trials into folds (1 = single split)
if nsplit > 1
    splittag = sprintf('_nsplit%d',nsplit);
else
    splittag = '';
end

[~,quality] = meg_quality_check();
ndata = numel(quality.subject);
idata2keep = quality.subject(~quality.excluded)';
ndata2keep = numel(idata2keep);
condname = {'_tracking', '_listen'};
soundname = {'_tar', '_dis'};
r2z = @(r)0.5*log((1+r)./(1-r)); % fisher z transform
figpath = paths.fig_dir;

cfg_fig = [];
cfg_fig.figpath = figpath;
cfg_fig.saveornot = saveornot;

load(paths.table,'data')

%
zdec_pitch = nan(ndata,301,2);
zdec_evidence = nan(ndata,301,2);
zdec_update = nan(ndata,301,2);

zdec_pitch_precision_jitter = nan(ndata,301,2,2);    % ndata x time x condition x high/low timing precision
zdec_evidence_precision_jitter = nan(ndata,301,2,2);

fprintf('Loading decoding results for \n')
for idata = 1:ndata
    fprintf('\tsubject %02d/%02d...',idata,ndata)
    if ~ismember(idata,idata2keep)
        fprintf('done.\n')
        continue
    else
        for icond = 1:2
            % pitch
            reg = 'pitch';
            fname = fullfile(paths.results_dir,sprintf('%s/out_dec_%s_%dhz_idata%d_ridge_alpha_500%s%s_eq-none%s',reg,reg,flowpass,idata,condname{icond},upper(soundname{isound}),splittag));
            if ~exist([fname '.mat'],'file')
                cfg = [];
                cfg.reg         = reg;
                cfg.subjects    = idata;
                cfg.cond        = icond;
                cfg.sound       = isound;
                cfg.equalize    = 'none';
                cfg.nsplit      = nsplit;
                decode_from_sensors(cfg);
            end
            load(fname)
            subdat = data(subidx,:);

            zdec_pitch(idata,:,icond) = r2z(out_dec.rdec);
            Ctru = out_dec.Ctru;
            Chat = out_dec.Chat;

            % jitter precision (around or far from beat grid)
            med_jitter = median(abs(subdat.jitter));
            ifilt = abs(subdat.jitter) < med_jitter; % precise
            zdec_pitch_precision_jitter(idata,:,icond,1) = zdec_filtered(Chat,Ctru,ifilt);
            zdec_pitch_precision_jitter(idata,:,icond,2) = zdec_filtered(Chat,Ctru,~ifilt);

            % evidence
            reg = 'evidence';
            fname = fullfile(paths.results_dir,sprintf('%s/out_dec_%s_%dhz_idata%d_ridge_alpha_500%s%s_eq-none%s',reg,reg,flowpass,idata,condname{icond},upper(soundname{isound}),splittag));
            if ~exist([fname '.mat'],'file')
                cfg = []; 
                cfg.reg         = reg;
                cfg.subjects    = idata;
                cfg.cond        = icond;
                cfg.sound       = isound;
                cfg.equalize    = 'none';
                cfg.nsplit      = nsplit;
                decode_from_sensors(cfg);
            end
            load(fname)
            subdat = data(subidx,:);

            zdec_evidence(idata,:,icond) = r2z(out_dec.rdec);
            Ctru = out_dec.Ctru;
            Chat = out_dec.Chat;

            % jitter precision (around or far from beat grid)
            med_jitter = median(abs(subdat.jitter));
            ifilt = abs(subdat.jitter) < med_jitter; % precise
            zdec_evidence_precision_jitter(idata,:,icond,1) = zdec_filtered(Chat,Ctru,ifilt);
            zdec_evidence_precision_jitter(idata,:,icond,2) = zdec_filtered(Chat,Ctru,~ifilt);

            % update (not defined for distractors)
            if isound == 1
                reg = 'update';
                fname = fullfile(paths.results_dir,sprintf('%s/out_dec_%s_%dhz_idata%d_ridge_alpha_500%s%s_eq-none%s',reg,reg,flowpass,idata,condname{icond},upper(soundname{isound}),splittag));
                if ~exist([fname '.mat'],'file')
                    cfg = [];
                    cfg.reg         = reg;
                    cfg.subjects    = idata;
                    cfg.cond        = icond;
                    cfg.sound       = isound;
                    cfg.equalize    = 'none';
                    cfg.nsplit      = nsplit;
                    decode_from_sensors(cfg);
                end
                load(fname)
                zdec_update(idata,:,icond) = r2z(out_dec.rdec);
            end
        end
    end
    fprintf('done.\n')
end

xvec = tim;

%% MAIN Fig. 3a (SUPP Fig. 4a): mean decoding t > 0, listen vs tracking (one-tailed: tracking > listen)
cfg = cfg_fig;
cfg.figname = sprintf('figure3_compare_conditions_pitch_%dHz%s_bars',flowpass,soundname{isound});
cfg.x = squeeze(mean(zdec_pitch(idata2keep,tim>0,[2 1]),2));
cfg.plotx = true;
cfg.ttest = true;
cfg.tail = 'left'; % listen < tracking
if isound == 1
    cfg.rgb = flipud(rgb_pitch);
else
    cfg.rgb = flipud((1+rgb_pitch)/2);
end
cfg.pbar = 0.7;
cfg.ytick = 0:.1:.2;
cfg.ylabel = 'mean decoding (z)';
cfg.ylim = [0 0.2];
cfg.xlabel = soundname{isound}(2:end);
cfg.xticklabel = fliplr({'tracking' 'listen'});
helper_plot_overall_bars(cfg)
[~,pval,~,stats] = ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
bf10 = bf.ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
fprintf('pitch(TAP) > pitch(LIS) (one-tail ttest)? : pval = %4.4f; t=%4.3f; bf10 = %4.3f\n',pval,stats.tstat,bf10)

cfg = cfg_fig;
cfg.figname = sprintf('figure3_compare_conditions_evidence_%dHz%s_bars',flowpass,soundname{isound});
cfg.x = squeeze(mean(zdec_evidence(idata2keep,tim>0,[2 1]),2));
cfg.plotx = true;
cfg.ttest = true;
cfg.tail = 'left'; % listen < tracking
if isound == 1
    cfg.rgb = flipud(rgb_evidence);
else
    cfg.rgb = flipud((1+rgb_evidence)/2);
end
cfg.pbar = 0.7;
cfg.ytick = 0:.1:.3;
if isound == 2
    cfg.ylim = [0 0.2];
else
cfg.ylim = [0 0.3];
end
cfg.ylabel = 'mean decoding (z)';
cfg.xlabel = soundname{isound}(2:end);
cfg.xticklabel = { 'listen' 'tracking'};
helper_plot_overall_bars(cfg)
[~,pval,~,stats] = ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
bf10 = bf.ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
fprintf('evidence(TAP) > evidence(LIS) (one-tail ttest)? : pval = %4.4f; t=%4.3f; bf10 = %4.3f\n',pval,stats.tstat,bf10)

if isound == 1 % update is not defined for distractors
    cfg = cfg_fig;
    cfg.figname = sprintf('figure3_compare_conditions_update_%dHz%s_bars',flowpass,soundname{isound});
    cfg.x = squeeze(mean(zdec_update(idata2keep,tim>0,[2 1]),2));
    cfg.plotx = true;
    cfg.ttest = true;
    cfg.tail = 'left'; % listen < tracking
    cfg.rgb = flipud(rgb_update);
    cfg.pbar = 0.7;
    cfg.ytick = 0:.1:.1;
    cfg.ylim = [0 0.1];
    cfg.xlabel = soundname{isound}(2:end);
    cfg.xticklabel = {'listen' 'tracking'};
    cfg.ylabel = 'mean decoding (z)';
    helper_plot_overall_bars(cfg)
    [~,pval,~,stats] = ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
    bf10 = bf.ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
    fprintf('update(TAP) > update(LIS) (one-tail ttest)? : pval = %5.4f; t=%4.3f; bf10 = %4.3f\n',pval,stats.tstat,bf10)
end

%% MAIN Fig. 3a right (SUPP Fig. 4a right): relative enhancement of each variable when tracking compared to listen
rgb_crel = [106,81,163;...
158,154,200;...
203,201,226]/255;

nres = 1e4; % number of boostrap resamples and number of permutations
rs = RandStream('mt19937ar','Seed',1); % fixed seed: reproducible bootstrap and permutations

if isound == 1
    X1 = squeeze(mean(zdec_pitch(idata2keep,tim>0,:),2));
    X2 = squeeze(mean(zdec_evidence(idata2keep,tim>0,:),2));
    X3 = squeeze(mean(zdec_update(idata2keep,tim>0,:),2));
    X_all  = {X1, X2, X3};
    reg_name = {'pitch' 'evidence' 'update'};
else
    X1 = squeeze(mean(zdec_pitch(idata2keep,tim>0,:),2));
    X2 = squeeze(mean(zdec_evidence(idata2keep,tim>0,:),2));
    X_all  = {X1, X2};
    reg_name = {'pitch' 'evidence'};
end
nreg = numel(X_all);

crel_mean = nan(1,nreg); % mean enhancement
crel_res = nan(nres,nreg); % bootstrap estimate of mean enhancement error/CI
for k = 1:nreg
    X = X_all{k};
    crel_mean(k) = (mean(X(:,1)) - mean(X(:,2))) ./ mean(X(:,2));
    % resample
    for ires = 1:nres
        idx = randi(rs, ndata2keep, ndata2keep, 1);
        X_res = X(idx,:);
        crel_res(ires,k) = (mean(X_res(:,1)) - mean(X_res(:,2))) ./ mean(X_res(:,2));
    end
end

crel_se = std(crel_res);
crel_ci = prctile(crel_res, [2.5 97.5], 1);

cfg = cfg_fig;
cfg.figname = sprintf('figure3_compare_conditions_all_%dHz%s_bars',flowpass,soundname{isound});
cfg.x = crel_mean*100;
cfg.xqt = [(crel_mean-crel_se)' (crel_mean+crel_se)']*100;
if isound == 1
    cfg.rgb = rgb_crel;
    cfg.pbar = 1;
    cfg.ylim = [-20 40];
    cfg.ytick = 0:20:40;
    % cfg.ytick = -20:20:50;
    % cfg.ylim = [-30 50];
else
    cfg.rgb = (1+rgb_crel)/2;
    cfg.pbar = 1;
    cfg.ylim = [-25 10];
    cfg.ytick = -20:10:10;
end
cfg.ylabel = sprintf('tracking vs listen (%%)');
cfg.xlabel = soundname{isound}(2:end);
cfg.xticklabel = reg_name;
helper_plot_overall_bars(cfg)

crel_perm = nan(nres,nreg);
p_val = nan(1,nreg); % is enhancement>0 (one-sided)
for k = 1:nreg
    X = X_all{k};
    for ires = 1:nres
        X_res = zeros(size(X));
        idx_res = rand(rs, ndata2keep, 1) < 0.5; % swap conditions
        X_res(idx_res,:) = X(idx_res,:); % no swap
        X_res(~idx_res,:) = fliplr(X(~idx_res,:));
        crel_perm(ires,k) = (mean(X_res(:,1)) - mean(X_res(:,2))) ./ mean(X_res(:,2));
    end
    p_val(k) = (sum(crel_perm(:,k) >= crel_mean(k)) + 1) / (nres + 1);
    fprintf('%s: enhancement =%3.0f ;\t se=±%3.0f;\tCI: [%3.0f %3.0f];\tpval = %3.4f\n',reg_name{k},crel_mean(k)*100,crel_se(k)*100,crel_ci(1,k)*100,crel_ci(2,k)*100,p_val(k))
end

%% MAIN Fig. 3b (SUPP Fig. 4b): time courses tracking vs listen
cfg = cfg_fig;
cfg.figname = sprintf('figure3_compare_conditions_pitch_%dHz%s',flowpass,soundname{isound});
cfg.zdec = zdec_pitch(idata2keep,:,:);
cfg.xvec = tim;
cfg.ylim = [-0.08/2 0.2];%[-0.05 .4]
cfg.pbar = 1;
cfg.statsbetween = true;
cfg.ytick = 0:.1:.2;
if isound == 1
    cfg.rgb = rgb_pitch;
else
    cfg.rgb = (1+rgb_pitch)/2;
end
helper_plot_decoding(cfg);


cfg = cfg_fig;
cfg.figname = sprintf('figure3_compare_conditions_evidence_%dHz%s',flowpass,soundname{isound});
cfg.zdec = zdec_evidence(idata2keep,:,:);
cfg.xvec = tim;
cfg.ylim = [-0.08 0.4];
cfg.pbar = 1;
cfg.statsbetween = true;
cfg.ytick = 0:.1:.4;
if isound == 1
    cfg.rgb = rgb_evidence;
else
    cfg.rgb = (1+rgb_evidence)/2;
end
helper_plot_decoding(cfg);


if isound == 1 % update is not defined for distractors
    cfg = cfg_fig;
    cfg.figname = sprintf('figure3_compare_conditions_update_%dHz%s',flowpass,soundname{isound});
    cfg.zdec = zdec_update(idata2keep,:,:);
    cfg.xvec = tim;
    cfg.ylim = [-0.08/4 0.1];
    cfg.pbar = 1;
    cfg.ytick = 0:.1:.1;
    cfg.statsbetween = true;
    cfg.rgb = rgb_update;
    helper_plot_decoding(cfg);
end

%% MAIN Fig. 3b, peak amplitude and latency, tracking vs listen (jackknifed peaks) 
regname = {'pitch','evidence','update'};
if isound == 1
    nvar = 3;
else
    nvar = 2; % update is not defined for distractors
end
N = ndata2keep;
t_fine = linspace(min(tim), max(tim), 10000);
xpeak_jk = nan(N,2,nvar); % peak latency: participant left out x condition x variable
ypeak_jk = nan(N,2,nvar); % peak amplitude
for ivar = 1:nvar
    switch ivar
        case 1; zdec_var = zdec_pitch;
        case 2; zdec_var = zdec_evidence;
        case 3; zdec_var = zdec_update;
    end
    for icond = 1:2
        x = zdec_var(idata2keep,:,icond);
        for idata = 1:N
            % leave one out
            x_jk = x(setdiff(1:N,idata),:);
            x_fine_jk = interp1(tim, mean(x_jk,1), t_fine, 'pchip');
            [ymax_jk, idxmax] = max(x_fine_jk);
            xpeak_jk(idata,icond,ivar) = t_fine(idxmax);
            ypeak_jk(idata,icond,ivar) = ymax_jk;
        end
    end
end

fprintf('Jackknifed peaks, tracking vs listen:\n')
for ivar = 1:nvar
    % amplitude, one-tailed: tracking > listen
    [~,~,~,STATS] = ttest(ypeak_jk(:,1,ivar),ypeak_jk(:,2,ivar));
    t_corrected = STATS.tstat/(N-1);
    PVAL = 1-tcdf(t_corrected,N-1);
    BF10 = bf.ttest('T',t_corrected,'N',N,'tail','right');
    fprintf('\t%s SOUND%d ttest TAP > LIS AMPLITUDE (one-tailed): t_jk = %5.5f; p = %5.5f; BF10 (one-sided) = %4.3f\n',regname{ivar},isound,t_corrected,PVAL,BF10)
    % latency, two-tailed
    [~,~,~,STATS] = ttest(xpeak_jk(:,1,ivar),xpeak_jk(:,2,ivar));
    t_corrected = STATS.tstat/(N-1);
    PVAL = 2*tcdf(-abs(t_corrected),N-1);
    BF10 = bf.ttest('T',t_corrected,'N',N);
    fprintf('\t%s SOUND%d ttest TAP vs LIS LATENCY (two-tailed): diff = %+3.0fms; t_jk = %5.5f; p = %5.5f; BF10 (two-sided) = %4.3f\n',regname{ivar},isound,1000*mean(xpeak_jk(:,1,ivar)-xpeak_jk(:,2,ivar)),t_corrected,PVAL,BF10)
end

%% MAIN Fig. 3c (SUPP Fig. 4c): effect of sound timing precision JITTER
% pitch precision
cfg = cfg_fig;
cfg.figname = sprintf('figure_precision_jitter_high_compare_conditions_pitch_%dHz%s_bars',flowpass,soundname{isound});
cfg.x = squeeze(mean(zdec_pitch_precision_jitter(idata2keep,tim>0,[2 1],1),2));
cfg.plotx = true;
cfg.ttest = true;
cfg.tail = 'left'; % listen < tracking
if isound == 1
    cfg.rgb = flipud(rgb_pitch);
else
    cfg.rgb = flipud((1+rgb_pitch)/2);
end
cfg.pbar = 0.7;
if isound == 2
    cfg.ytick = 0:.1:.2;
    cfg.ylim = [0 0.2];
else
    cfg.ytick = 0:.1:.3;
    cfg.ylim = [0 0.3];
end
cfg.xlabel = 'high precision';
cfg.xticklabel = {'listen','tracking'};
cfg.ylabel = 'mean decoding (z)';
helper_plot_overall_bars(cfg)
[~,pval,~,stats] = ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
fprintf('high precision pitch(TAP) > pitch(LIS) (one-tail ttest)? : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)

cfg = cfg_fig;
cfg.figname = sprintf('figure_precision_jitter_low_compare_conditions_pitch_%dHz%s_bars',flowpass,soundname{isound});
cfg.x = squeeze(mean(zdec_pitch_precision_jitter(idata2keep,tim>0,[2 1],2),2));
cfg.plotx = true;
cfg.ttest = true;
cfg.tail = 'left'; % listen < tracking
if isound == 1
    cfg.rgb = flipud(rgb_pitch);
else
    cfg.rgb = flipud((1+rgb_pitch)/2);
end
cfg.pbar = 0.7;
if isound == 2
    cfg.ytick = 0:.1:.2;
    cfg.ylim = [0 0.2];
else
    cfg.ytick = 0:.1:.3;
    cfg.ylim = [0 0.3];
end
cfg.xlabel = 'low precision';
cfg.xticklabel = {'listen','tracking'};
cfg.ylabel = 'mean decoding (z)';
helper_plot_overall_bars(cfg)
[~,pval,ci,stats] = ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
fprintf('low precision pitch(TAP) > pitch(LIS) (one-tail ttest)? : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)

cfg = cfg_fig;
cfg.figname = sprintf('figure_precision_jitter_compare_conditions_pitch_%dHz%s_bars',flowpass,soundname{isound});
cfg.x = [squeeze(mean(zdec_pitch_precision_jitter(idata2keep,tim>0,1,:),2)) squeeze(mean(zdec_pitch_precision_jitter(idata2keep,tim>0,2,:),2))];
cfg.plotx = true;
cfg.ttest = true;
if isound == 1
    cfg.rgb = [rgb_pitch(1,:);rgb_pitch(1,:);rgb_pitch(2,:);rgb_pitch(2,:)];
else
    cfg.rgb = (1+[rgb_pitch(1,:);rgb_pitch(1,:);rgb_pitch(2,:);rgb_pitch(2,:)])/2;
end
cfg.pbar = 1;
cfg.ytick = 0:.1:.3;
cfg.ylim = [0 0.3];
cfg.xlabel = soundname{isound}(2:end);
cfg.xticklabel = {'good','bad','good','bad'};
cfg.ylabel = 'mean decoding (z)';
helper_plot_overall_bars(cfg)
anova_2x2_ttest(squeeze(mean(zdec_pitch_precision_jitter(idata2keep,tim>0,:,:),2)),{'condition','precision'}, ...
    sprintf('pitch %s, mean decoding t > 0',soundname{isound}(2:end)));

% evidence precision
cfg = cfg_fig;
cfg.figname = sprintf('figure_precision_jitter_high_compare_conditions_evidence_%dHz%s_bars',flowpass,soundname{isound});
cfg.x = squeeze(mean(zdec_evidence_precision_jitter(idata2keep,tim>0,[2 1],1),2));
cfg.plotx = true;
cfg.ttest = true;
cfg.tail = 'left'; % listen < tracking
if isound == 1
    cfg.rgb = flipud(rgb_evidence);
else
    cfg.rgb = flipud((1+rgb_evidence)/2);
end
cfg.pbar = 0.7;
cfg.ytick = 0:.1:.3;
cfg.ylim = [0 0.3];
cfg.xlabel = 'high precision';
cfg.xticklabel = {'listen','tracking'};
cfg.ylabel = 'mean decoding (z)';
helper_plot_overall_bars(cfg)
[~,pval] = ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
fprintf('high precision evidence(TAP) > evidence(LIS) (one-tail ttest)? : pval = %4.3f\n',pval)

cfg = cfg_fig;
cfg.figname = sprintf('figure_precision_jitter_low_compare_conditions_evidence_%dHz%s_bars',flowpass,soundname{isound});
cfg.x = squeeze(mean(zdec_evidence_precision_jitter(idata2keep,tim>0,[2 1],2),2));
cfg.plotx = true;
cfg.ttest = true;
cfg.tail = 'left'; % listen < tracking
if isound == 1
    cfg.rgb = flipud(rgb_evidence);
else
    cfg.rgb = flipud((1+rgb_evidence)/2);
end
cfg.pbar = 0.7;
cfg.ytick = 0:.1:.3;
cfg.ylim = [0 0.3];
cfg.xlabel = 'low precision';
cfg.xticklabel = {'listen','tracking'};
cfg.ylabel = 'mean decoding (z)';
helper_plot_overall_bars(cfg)
[H,pval] = ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
fprintf('low precision evidence(TAP) > evidence(LIS) (one-tail ttest)? : pval = %4.4f\n',pval)

cfg = cfg_fig;
cfg.figname = sprintf('figure_precision_jitter_compare_conditions_evidence_%dHz%s_bars',flowpass,soundname{isound});
cfg.x = [squeeze(mean(zdec_evidence_precision_jitter(idata2keep,tim>0,1,:),2)) squeeze(mean(zdec_evidence_precision_jitter(idata2keep,tim>0,2,:),2))];
cfg.plotx = true;
cfg.ttest = true;
if isound == 1
    cfg.rgb = [rgb_evidence(1,:);rgb_evidence(1,:);rgb_evidence(2,:);rgb_evidence(2,:)];
else
    cfg.rgb = (1+[rgb_evidence(1,:);rgb_evidence(1,:);rgb_evidence(2,:);rgb_evidence(2,:)])/2;
end
cfg.pbar = 1;
cfg.ytick = 0:.1:.3;
cfg.ylim = [0 0.3];
cfg.xlabel = soundname{isound}(2:end);
cfg.xticklabel = {'good','bad','good','bad'};
cfg.ylabel = 'mean decoding (z)';
helper_plot_overall_bars(cfg)
anova_2x2_ttest(squeeze(mean(zdec_evidence_precision_jitter(idata2keep,tim>0,:,:),2)),{'condition','precision'}, ...
    sprintf('evidence %s, mean decoding t > 0',soundname{isound}(2:end)));
