%% analyses_figure_2 
% Fig. 2 and Supp. Figs. 1, 2, 3
% each decoding result is loaded, or computed first if it does not exist (decode_from_sensors)
% part 1 - isound = 1 -> Fig. 2a,b,d,e and Supp. Fig. 2 (targets),
%          isound = 2 -> Supp. Fig. 1 (distractors)
% part 2 - icond = 2 -> Fig. 2c, Supp. Fig. 3 (listen); icond = 1 -> Fig. 2f (tracking)
% superimpose pitch, evidence and update (targets, isound = 1) or pitch and evidence
% (distractors, isound = 2: update is not defined for distractors), decoded without equalization
% (decode_from_sensors, cfg.equalize = 'none',take the 'decoding per
% condition')
% DON'T COMPARE TAR AND DIS INSIDE CONDITION! NOT EQUALIZED!

clearvars
close all
clc

isound = 2; % 1 = targets (pitch, evidence, update), 2 = distractors (pitch, evidence), always lighter colors
saveornot = false;

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

yl = [-0.05 .4];

paths = config_paths();

flowpass = 8;
nsplit = 10; % decoding averaged over nsplit random splits of the trials into folds (1 = single split)
if nsplit > 1
    splittag = sprintf('_nsplit%d',nsplit);
else
    splittag = '';
end

% remove participants with bad MEG data
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

% contains pitch, evidence, update, iscor
load(paths.table,'data')

%
zdec_pitch = nan(ndata,301,2);
zdec_pitch_corerr = nan(ndata,301,2,2);
zdec_evidence = nan(ndata,301,2);
zdec_evidence_corerr = nan(ndata,301,2,2);
zdec_update = nan(ndata,301,2);
zdec_update_corerr = nan(ndata,301,2,2);

fprintf('Loading decoding results for \n')
for idata = 1:ndata
    fprintf('\tsubject %02d/%02d...',idata,ndata)
    if ~ismember(idata,idata2keep)
        fprintf('done.\n')
        continue
    else
        for icond = 1:2
            reg = 'pitch';
            fname = fullfile(paths.results_dir,sprintf('%s/out_dec_%s_%dhz_idata%d_ridge_alpha_500%s%s_eq-none%s',reg,reg,flowpass,idata,condname{icond},upper(soundname{isound}),splittag));
            if ~exist([fname '.mat'],'file') % decode if not existing
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
            % cor/err
            ifilt = subdat.iscor;
            zdec_pitch_corerr(idata,:,icond,1) = zdec_filtered(Chat,Ctru,ifilt);
            zdec_pitch_corerr(idata,:,icond,2) = zdec_filtered(Chat,Ctru,~ifilt);

            reg = 'evidence';
            fname = fullfile(paths.results_dir,sprintf('%s/out_dec_%s_%dhz_idata%d_ridge_alpha_500%s%s_eq-none%s',reg,reg,flowpass,idata,condname{icond},upper(soundname{isound}),splittag));
            if ~exist([fname '.mat'],'file') % decode if not existing
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
            % cor/err
            ifilt = subdat.iscor;
            zdec_evidence_corerr(idata,:,icond,1) = zdec_filtered(Chat,Ctru,ifilt);
            zdec_evidence_corerr(idata,:,icond,2) = zdec_filtered(Chat,Ctru,~ifilt);

            if isound == 1 % update is not defined for distractors
                reg = 'update';
                fname = fullfile(paths.results_dir,sprintf('%s/out_dec_%s_%dhz_idata%d_ridge_alpha_500%s%s_eq-none%s',reg,reg,flowpass,idata,condname{icond},upper(soundname{isound}),splittag));
                if ~exist([fname '.mat'],'file') % decode if not existing
                    cfg = [];
                    cfg.reg = reg;
                    cfg.subjects = idata;
                    cfg.cond = icond;
                    cfg.sound = isound;
                    cfg.equalize = 'none';
                    cfg.nsplit = nsplit;
                    decode_from_sensors(cfg);
                end
                load(fname)
                subdat = data(subidx,:);
                zdec_update(idata,:,icond) = r2z(out_dec.rdec);
                Ctru = out_dec.Ctru;
                Chat = out_dec.Chat;
                % cor/err
                ifilt = subdat.iscor;
                zdec_update_corerr(idata,:,icond,1) = zdec_filtered(Chat,Ctru,ifilt);
                zdec_update_corerr(idata,:,icond,2) = zdec_filtered(Chat,Ctru,~ifilt);
            end
        end
    end
    fprintf('done.\n')
end

xvec = tim;

%% MAIN Fig. 2a,d: extract peak latency + amplitude per regressor
fprintf('Jackknifed mean peak:\n')
xpeak_jk = nan(ndata2keep,2,3);
ypeak_jk = nan(ndata2keep,2,3);
xpeak = nan(2,3);
ypeak = nan(2,3);
N = ndata2keep;

for icond = 1:2
    reg = 'pitch';
    x = zdec_pitch(idata2keep,:,icond);
    % mean of all participants
    t_fine = linspace(min(xvec), max(xvec), 10000);
    x_fine = interp1(xvec, mean(x,1), t_fine, 'pchip');
    [ymax, idxmax] = max(x_fine);
    ypeak(icond,1) = ymax;
    xpeak(icond,1) = t_fine(idxmax);
    % jackknife mean
    for idata = 1:ndata2keep
        % leave one out
        x_jk = x(setdiff(1:ndata2keep,idata),:);
        x_fine_jk = interp1(xvec, mean(x_jk,1), t_fine, 'pchip');
        [ymax_jk, idxmax] = max(x_fine_jk);
        xpeak_jk(idata,icond,1) = t_fine(idxmax);
        ypeak_jk(idata,icond,1) = ymax_jk;
    end
    
    xpeak_se = sqrt((N-1)/N * sum((xpeak_jk(:,icond,1) - mean(xpeak_jk(:,icond,1))).^2));
    ypeak_se = sqrt((N-1)/N * sum((ypeak_jk(:,icond,1) - mean(ypeak_jk(:,icond,1))).^2));
    fprintf('\t%s cond%d sound%d : \t\txpeak = %3.0f±%1.0fms ypeak = %5.3f±%5.3f\n',reg,icond,isound,1000*xpeak(icond,1),1000*xpeak_se,ypeak(icond,1),ypeak_se)

    reg = 'evidence';
    x = zdec_evidence(idata2keep,:,icond);
    % mean of all participants
    t_fine = linspace(min(xvec), max(xvec), 10000);
    x_fine = interp1(xvec, mean(x,1), t_fine, 'pchip');
    [ymax,idxmax] = max(x_fine);
    ypeak(icond,2) = ymax;
    xpeak(icond,2) = t_fine(idxmax);
    % jackknife mean
    for idata = 1:ndata2keep
        % leave one out
        x_jk = x(setdiff(1:ndata2keep,idata),:);
        x_fine_jk = interp1(xvec, mean(x_jk,1), t_fine, 'pchip');
        [ymax_jk, idxmax] = max(x_fine_jk);
        xpeak_jk(idata,icond,2) = t_fine(idxmax);
        ypeak_jk(idata,icond,2) = ymax_jk;
    end
    xpeak_se = sqrt((N-1)/N * sum((xpeak_jk(:,icond,2) - mean(xpeak_jk(:,icond,2))).^2));
    ypeak_se = sqrt((N-1)/N * sum((ypeak_jk(:,icond,2) - mean(ypeak_jk(:,icond,2))).^2));
    fprintf('\t%s cond%d sound%d : \txpeak = %3.0f±%1.0fms ypeak = %5.3f±%5.3f\n',reg,icond,isound,1000*xpeak(icond,2),1000*xpeak_se,ypeak(icond,2),ypeak_se)

    if isound == 1 % update is not defined for distractors
        reg = 'update';
        x = zdec_update(idata2keep,:,icond);
        % mean of all participants
        t_fine = linspace(min(xvec), max(xvec), 10000);
        x_fine = interp1(xvec, mean(x,1), t_fine, 'pchip');
        [ymax,idxmax] = max(x_fine);
        ypeak(icond,3) = ymax;
        xpeak(icond,3) = t_fine(idxmax);
        % jackknife mean
        for idata = 1:ndata2keep
            % leave one out
            x_jk = x(setdiff(1:ndata2keep,idata),:);
            x_fine_jk = interp1(xvec, mean(x_jk,1), t_fine, 'pchip');
            [ymax_jk, idxmax] = max(x_fine_jk);
            xpeak_jk(idata,icond,3) = t_fine(idxmax);
            ypeak_jk(idata,icond,3) = ymax_jk;
        end
        xpeak_se = sqrt((N-1)/N * sum((xpeak_jk(:,icond,3) - mean(xpeak_jk(:,icond,3))).^2));
        ypeak_se = sqrt((N-1)/N * sum((ypeak_jk(:,icond,3) - mean(ypeak_jk(:,icond,3))).^2));
        fprintf('\t%s cond%d sound%d : \t\txpeak = %3.0f±%1.0fms ypeak = %5.3f±%5.3f\n',reg,icond,isound,1000*xpeak(icond,3),1000*xpeak_se,ypeak(icond,3),ypeak_se)
    end
end

% compare the variables within each condition (two-tailed jackknife t-tests)
regname = {'pitch','evidence','update'};
if isound == 1
    pairs = [1 2; 1 3; 2 3];
else
    pairs = [1 2]; % update is not defined for distractors
end
for icond = 1:2
    for ipair = 1:size(pairs,1)
        ireg1 = pairs(ipair,1);
        ireg2 = pairs(ipair,2);
        X = xpeak_jk;
        [~,~,~,STATS] = ttest(X(:,icond,ireg2),X(:,icond,ireg1));
        t_corrected = STATS.tstat/(N-1);
        PVAL = 2*tcdf(-abs(t_corrected),N-1);
        fprintf('\tcond%d sound%d %s vs %s LATENCY (two-tailed): diff = %+3.0fms; t_jk = %5.5f; p = %5.5f \n',icond,isound,regname{ireg2},regname{ireg1},1000*mean(X(:,icond,ireg2)-X(:,icond,ireg1)),t_corrected,PVAL)
        X = ypeak_jk;
        [~,~,~,STATS] = ttest(X(:,icond,ireg2),X(:,icond,ireg1));
        t_corrected = STATS.tstat/(N-1);
        PVAL = 2*tcdf(-abs(t_corrected),N-1);
        fprintf('\tcond%d sound%d %s vs %s AMPLITUDE (two-tailed): diff = %+5.3f; t_jk = %5.5f; p = %5.5f \n',icond,isound,regname{ireg2},regname{ireg1},mean(X(:,icond,ireg2)-X(:,icond,ireg1)),t_corrected,PVAL)
    end
end


%% MAIN Fig. 2a,d (SUPP Fig. 1a,c): compare accumulation regressors in each condition
for icond = 1:2
    cfg = cfg_fig;
    if isound == 1
        cfg.figname = sprintf('fig2_decoding%s%s',condname{icond},soundname{isound});
    else
        cfg.figname = sprintf('SUPP_fig1_decoding%s%s',condname{icond},soundname{isound});
    end
    if isound == 1
        cfg.zdec = cat(3,zdec_pitch(idata2keep,:,icond),zdec_evidence(idata2keep,:,icond),zdec_update(idata2keep,:,icond));
    else % update is not defined for distractors
        cfg.zdec = cat(3,zdec_pitch(idata2keep,:,icond),zdec_evidence(idata2keep,:,icond));
    end
    cfg.xvec = xvec;
    cfg.ylim = yl;
    cfg.stats0 = true;
    if icond == 1
        cfg.rgb = rgb_tap;
    else
        cfg.rgb = rgb_lis;
    end
    if isound == 2
        cfg.rgb = (1+cfg.rgb)/2;
    end
    stat = helper_plot_decoding(cfg);
    % significant time windows (cluster-based permutation test > 0)
    regname = {'pitch','evidence','update'};
    for ireg = 1:size(cfg.zdec,3)
        cl = stat.stats0(ireg).clusters;
        cl = cl(cl(:,3) < 0.05,:);
        w = '';
        for ic = 1:size(cl,1)
            if cl(ic,3) < 0.001
                ptxt = 'p < 0.001';
            else
                ptxt = sprintf('p = %.3f',cl(ic,3));
            end
            w = [w sprintf('%.3f to %.3f s (%s)  ',cl(ic,1),cl(ic,2),ptxt)];
        end
        if isempty(w), w = 'none'; end
        fprintf('significant decoding window %s %s: %s\n',regname{ireg},upper(condname{icond}(2:end)),w)
    end
end

%% MAIN Fig. 2b,e (SUPP Fig. 1b,d): correct/error of accumulation regressors in each condition
for icond = 1:2
    fprintf('ttest (one-tailed) CORRECT>ERROR in %s for %s\n',upper(condname{icond}(2:end)),upper(soundname{isound}(2:end)))
    cfg = cfg_fig;
    if isound == 1
        cfg.figname = sprintf('fig2_correct_error_pitch%s%s',condname{icond},soundname{isound});
    else
        cfg.figname = sprintf('SUPP_fig1_correct_error_pitch%s%s',condname{icond},soundname{isound});
    end
    cfg.x = squeeze(mean(zdec_pitch_corerr(idata2keep,tim>0,icond,:),2));
    cfg.plotx = true;
    cfg.ttest = true;
    cfg.tail = 'right';   % correct > error
    if icond == 1
        cfg.rgb = [rgb_tap(1,:);rgb_tap(1,:)];
    else
        cfg.rgb = [rgb_lis(1,:);rgb_lis(1,:)];
    end
    if isound == 2
        cfg.rgb = (1+cfg.rgb)/2;
    end
    cfg.pbar = 0.6;
    cfg.ylim = yl;
    cfg.xlabel = soundname{isound}(2:end);
    cfg.xticklabel = {'correct' 'error'};
    cfg.ylabel = 'mean decoding (z)';
    helper_plot_overall_bars(cfg)
    [~,pval,~,stats]=ttest(cfg.x(:,1),cfg.x(:,2),'Tail','right');
    bf10 = bf.ttest(cfg.x(:,1)-cfg.x(:,2),'tail','right'); % one-sided BF10, correct > error
    fprintf('\tpitch: \t\tp = %5.5f ,\tt = %5.5f ,\tBF10 = %4.3f\n',pval,stats.tstat,bf10)

    cfg = cfg_fig;
    if isound == 1
        cfg.figname = sprintf('fig2_correct_error_evidence%s%s',condname{icond},soundname{isound});
    else
        cfg.figname = sprintf('SUPP_fig1_correct_error_evidence%s%s',condname{icond},soundname{isound});
    end
    cfg.x = squeeze(mean(zdec_evidence_corerr(idata2keep,tim>0,icond,:),2));
    cfg.plotx = true;
    cfg.ttest = true;
    cfg.tail = 'right';   % correct > error
    if icond == 1
        cfg.rgb = [rgb_tap(2,:);rgb_tap(2,:)];
    else
        cfg.rgb = [rgb_lis(2,:);rgb_lis(2,:)];
    end
    if isound == 2
        cfg.rgb = (1+cfg.rgb)/2;
    end
    cfg.pbar = 0.6;
    cfg.ylim = yl;
    cfg.xlabel = soundname{isound}(2:end);
    cfg.xticklabel = {'correct' 'error'};
    cfg.ylabel = 'mean decoding (z)';
    helper_plot_overall_bars(cfg)
    [~,pval,~,stats]=ttest(cfg.x(:,1),cfg.x(:,2),'Tail','right');
    bf10 = bf.ttest(cfg.x(:,1)-cfg.x(:,2),'tail','right'); % one-sided BF10, correct > error
    fprintf('\tevidence: \tp = %5.5f ,\tt = %5.5f ,\tBF10 = %4.3f\n',pval,stats.tstat,bf10)

    if isound == 1 % update is not defined for distractors
        cfg = cfg_fig;
        cfg.figname = sprintf('fig2_correct_error_update%s%s',condname{icond},soundname{isound});
        cfg.x = squeeze(mean(zdec_update_corerr(idata2keep,tim>0,icond,:),2));%,...
        cfg.plotx = true;
        cfg.ttest = true;
        cfg.tail = 'right';   % correct > error
        if icond == 1
            cfg.rgb = [rgb_tap(3,:);rgb_tap(3,:)];
        else
            cfg.rgb = [rgb_lis(3,:);rgb_lis(3,:)];
        end
        if isound == 2
            cfg.rgb = (1+cfg.rgb)/2;
        end
        cfg.pbar = 0.6;
        cfg.ylim = yl;
        cfg.xlabel = soundname{isound}(2:end);
        cfg.xticklabel = {'correct' 'error'};
        cfg.ylabel = 'mean decoding (z)';
        helper_plot_overall_bars(cfg)
        [~,pval,~,stats]=ttest(cfg.x(:,1),cfg.x(:,2),'Tail','right');
        bf10 = bf.ttest(cfg.x(:,1)-cfg.x(:,2),'tail','right'); % one-sided BF10, correct > error
        fprintf('\tupdate: \tp = %5.5f ,\tt = %5.5f ,\tBF10 = %4.3f\n',pval,stats.tstat,bf10)
    end
end


%% SUPP Fig. 2a,b,c: time course correct/error
rgb_pitch = [rgb_tap(1,:);rgb_lis(1,:)];
rgb_evidence = [rgb_tap(2,:);rgb_lis(2,:)];
rgb_update = [rgb_tap(3,:);rgb_lis(3,:)];
yl_supp = [-0.1 .5];
for icond = 1:2
    cfg = cfg_fig;
    if isound == 1
        cfg.figname = sprintf('SUPP_fig2a_correct_error_timecourse_pitch%s%s',condname{icond},soundname{isound});
    else
        cfg.figname = sprintf('correct_error_timecourse_pitch%s%s',condname{icond},soundname{isound});
    end
    cfg.zdec = squeeze(zdec_pitch_corerr(idata2keep,:,icond,:));
    cfg.xvec = xvec;
    cfg.ylim = yl_supp/2;
    cfg.statsbetween = true;
    cfg.ytick = -.1:.1:.5;
    cfg.legend = {'correct','error'};
    cfg.rgb = [rgb_pitch(icond,:);(1+rgb_pitch(icond,:))/2];
    if isound == 2
        cfg.rgb = (1+cfg.rgb)/2;
    end
    helper_plot_decoding(cfg);

    cfg = cfg_fig;
    if isound == 1
        cfg.figname = sprintf('SUPP_fig2b_correct_error_timecourse_evidence%s%s',condname{icond},soundname{isound});
    else
        cfg.figname = sprintf('correct_error_timecourse_evidence%s%s',condname{icond},soundname{isound});
    end
    cfg.zdec = squeeze(zdec_evidence_corerr(idata2keep,:,icond,:));
    cfg.xvec = xvec;
    cfg.ylim = yl_supp;
    cfg.ytick = 0:.1:.5;
    cfg.statsbetween = true;
    cfg.legend = {'correct','error'};
    cfg.rgb = [rgb_evidence(icond,:);(1+rgb_evidence(icond,:))/2];
    if isound == 2
        cfg.rgb = (1+cfg.rgb)/2;
    end
    helper_plot_decoding(cfg);

    if isound == 1 % update is not defined for distractors
        cfg = cfg_fig;
        cfg.figname = sprintf('SUPP_fig2c_correct_error_timecourse_update%s%s',condname{icond},soundname{isound});
        cfg.zdec = squeeze(zdec_update_corerr(idata2keep,:,icond,:));
        cfg.xvec = xvec;
        cfg.ylim = yl_supp/4;
        cfg.ytick = -.1:.1:.5;
        cfg.statsbetween = true;
        cfg.legend = {'correct','error'};
        cfg.rgb = [rgb_update(icond,:);(1+rgb_update(icond,:))/2];
        helper_plot_decoding(cfg);
    end
end


%% PART 2: Fig. 2c,f and Supp. Fig. 3, targets vs distractors
% compare TAR/DIS for pitch and evidence
% take the 'decoding per soundtype': decode_from_sensors with cfg.equalize = 'soundtype'
% (targets and distractors equalized on dfq within each condition)
% DON'T COMPARE CONDITIONS! NOT EQUALIZED!

clearvars
close all
clc

icond = 2; % 1 = tracking, 2 = listen
saveornot = false;

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

yl = [-0.05 .4];

paths = config_paths();

rgb = lines;

flowpass = 8;
nsplit = 10;
if nsplit > 1
    splittag = sprintf('_nsplit%d',nsplit);
else
    splittag = '';
end

[~,quality] = meg_quality_check();
ndata = height(quality);                         
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

zdec_pitch = nan(ndata,301,2);            % ndata x time x soundtype
zdec_evidence = nan(ndata,301,2);

fprintf('Loading decoding results for \n')
for idata = 1:ndata
    fprintf('\tsubject %02d/%02d...',idata,ndata)
    if ~ismember(idata,idata2keep)
        fprintf('done.\n')
        continue
    else
        for isound = 1:2
            reg = 'pitch';
            fname = fullfile(paths.results_dir,sprintf('%s/out_dec_%s_%dhz_idata%d_ridge_alpha_500%s%s_eq-soundtype%s',reg,reg,flowpass,idata,condname{icond},upper(soundname{isound}),splittag));
            if ~exist([fname '.mat'],'file') % decode if not existing
                cfg = [];
                cfg.reg         = reg;
                cfg.subjects    = idata;
                cfg.cond        = icond;
                cfg.sound       = isound;
                cfg.equalize    = 'soundtype';
                cfg.nsplit      = nsplit;
                decode_from_sensors(cfg);
            end
            load(fname)
            zdec_pitch(idata,:,isound) = r2z(out_dec.rdec);

            reg = 'evidence';
            fname = fullfile(paths.results_dir,sprintf('%s/out_dec_%s_%dhz_idata%d_ridge_alpha_500%s%s_eq-soundtype%s',reg,reg,flowpass,idata,condname{icond},upper(soundname{isound}),splittag));
            if ~exist([fname '.mat'],'file')
                cfg = [];
                cfg.reg         = reg;
                cfg.subjects    = idata;
                cfg.cond        = icond;
                cfg.sound       = isound;
                cfg.equalize    = 'soundtype';
                cfg.nsplit      = nsplit;
                decode_from_sensors(cfg);
            end
            load(fname)
            zdec_evidence(idata,:,isound) = r2z(out_dec.rdec);
        end
    end
    fprintf('done.\n')
end

xvec = tim;

%% MAIN Fig. 2c (listen) or 2f (tracking): targets versus distractors, no belief update
cfg = cfg_fig;
cfg.figname = sprintf('fig2_target_selectivity%s',condname{icond});
cfg.x = [mean(zdec_pitch(idata2keep,tim>0,1)-zdec_pitch(idata2keep,tim>0,2),2),...
                mean(zdec_evidence(idata2keep,tim>0,1)-zdec_evidence(idata2keep,tim>0,2),2)];
cfg.plotx = true;
cfg.ttest = false;
if icond == 1
    cfg.rgb = rgb_tap;
else
    cfg.rgb = rgb_lis;
end
cfg.pbar = 0.6;
cfg.ylim = [-.1 .15];
cfg.ytick = [-.1,0,.1];
cfg.xlabel = condname{icond}(2:end);
cfg.xticklabel = {'pitch' 'evidence'};
cfg.ylabel = sprintf('decoding difference (z)\n targets minus distractors');
helper_plot_overall_bars(cfg)

% one-sided tests: targets > distractors
[~,pval,~,stats]=ttest(cfg.x(:,1),0,'tail','right');
bf10 = bf.ttest(cfg.x(:,1),'tail','right');
fprintf('PITCH tar minus dis against 0 (one-tailed): p = %4.4f, t = %4.4f, BF10 = %4.3f\n',pval,stats.tstat,bf10);
[~,pval,~,stats]=ttest(cfg.x(:,2),0,'tail','right');
bf10 = bf.ttest(cfg.x(:,2),'tail','right');
fprintf('EVIDENCE tar minus dis against 0 (one-tailed): p = %4.4f, t = %4.4f, BF10 = %4.3f\n',pval,stats.tstat,bf10);

%% SUPP Fig. 3a,b: compare targets/distractors for each regressor
cfg = cfg_fig;
cfg.figname = sprintf('SUPP_fig3a_target_distractor_pitch%s',condname{icond});
cfg.zdec = squeeze(zdec_pitch(idata2keep,:,:));
cfg.xvec = tim;
cfg.ylim = yl/2;
cfg.statsbetween = true;

if icond == 1
    cfg.rgb = [rgb_tap(1,:);(1+rgb_tap(1,:))/2];
else
    cfg.rgb = [rgb_lis(1,:);(1+rgb_lis(1,:))/2];
end
helper_plot_decoding(cfg);

cfg = cfg_fig;
cfg.figname = sprintf('SUPP_fig3b_target_distractor_evidence%s',condname{icond});
cfg.zdec = zdec_evidence(idata2keep,:,:);
cfg.xvec = tim;
cfg.ylim = yl;
cfg.statsbetween = true;
if icond == 1
    cfg.rgb = [rgb_tap(2,:);(1+rgb_tap(2,:))/2];
else
    cfg.rgb = [rgb_lis(2,:);(1+rgb_lis(2,:))/2];
end
helper_plot_decoding(cfg); 

%% SUPP Fig. 3: percentage of tones discarded by the equalization
% same equalization as decode_from_sensors with cfg.equalize = 'soundtype' (same seed),
% computed from the data table, in both conditions
pdiscard = nan(ndata,1);
for idata = idata2keep
    ntone = 0;
    nkept = 0;
    for jcond = 1:2 % tracking•listen
        rows = find(data.subject == idata & data.('tap/lis') == jcond);
        rng(idata*100,'twister');
        subset = equalize_trials(data(rows,:),'dfq');
        ntone = ntone + numel(rows);
        nkept = nkept + sum(subset);
    end
    pdiscard(idata) = 100*(1 - nkept/ntone);
end
fprintf('tones discarded by the equalization (both conditions): %.2f ± %.2f %% (mean ± s.e.m.)\n', ...
    mean(pdiscard(idata2keep)),std(pdiscard(idata2keep))/sqrt(ndata2keep));