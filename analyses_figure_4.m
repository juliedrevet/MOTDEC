%% analyses_figure_4 
% Fig. 4 and Supp. Figs. 5, 6, 7
% each decoding result is loaded, or computed first if it does not exist
% part 1: isound = 1 -> Fig. 4b,c, isound = 2 -> Supp. Fig. 6a
% part 2: isound = 1 -> Fig. 4d, isound = 2 -> Supp. Fig. 6b
% part 3: noise_level = 0.5 -> Supp. Fig. 5a, 1 -> Supp. Fig. 5b
% part 4: icond = 1 (tracking) and 2 (listen) -> Supp. Fig. 7
% transfer between conditions (decode_transfer_from_sensors, cfg.across = 'condition',
% targets (Fig. 4b,c) or distractors (isound = 2, Supp. Fig. 6a), no equalization): 
% within (trained and tested on the same condition) and transfer (trained on 
% the other condition) are computed with the same folds and tested on the same trials

clearvars
close all
clc

paths = config_paths();

isound = 1; % 1 = targets; 2 = distractors
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

rgb_pitch = [rgb_tap(1,:);rgb_lis(1,:)];
rgb_evidence = [rgb_tap(2,:);rgb_lis(2,:)];

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
condname = {'_tracking', '_listen'};
soundname = {'_tar', '_dis'};
r2z = @(r)0.5*log((1+r)./(1-r));
figpath = paths.fig_dir;

cfg_fig = [];
cfg_fig.figpath = figpath;
cfg_fig.saveornot = saveornot;

zdec_dir = paths.results_dir;
% file of the decoder trained on condition icond_trn and tested on condition icond_tst
transfer_file = @(reg,idata,icond_trn,icond_tst) fullfile(zdec_dir,reg,sprintf('transfer_out_dec_%s_%dhz_idata%d_ridge_alpha_500_TRN%s_TST%s%s_eq-none%s', ...
    reg,flowpass,idata,condname{icond_trn},condname{icond_tst},upper(soundname{isound}),splittag));

% initialize
zdec_pitch = nan(ndata,301,2);             % within, last dim = condition
zdec_evidence = nan(ndata,301,2);
zdec_pitch_transfer = nan(ndata, 301, 2);  % last dim = direction
zdec_evidence_transfer = nan(ndata, 301, 2);

transfer_pairs = [1 2; 2 1];
fprintf('Loading decoding results for \n')
for idata = 1:ndata
    fprintf('\tsubject %02d/%02d...',idata,ndata)
    if ~ismember(idata,idata2keep)
        fprintf('not used.\n')
        continue
    else
        % load transfer
        for ipair = 1:2
            icond_trn = transfer_pairs(ipair, 1);
            icond_tst = transfer_pairs(ipair, 2);
            if ~exist([transfer_file('pitch',idata,icond_trn,icond_tst) '.mat'],'file')
                cfg = []; 
                cfg.reg         = 'pitch';
                cfg.across      = 'condition';
                cfg.sound       = isound;
                cfg.subjects    = idata;
                cfg.nsplit      = nsplit;
                decode_transfer_from_sensors(cfg);
            end
            load(transfer_file('pitch',idata,icond_trn,icond_tst), 'out_dec')
            zdec_pitch_transfer(idata, :, ipair) = r2z(out_dec.rdec);

            if ~exist([transfer_file('evidence',idata,icond_trn,icond_tst) '.mat'],'file')
                cfg = [];
                cfg.reg         = 'evidence';
                cfg.across      = 'condition';
                cfg.sound       = isound;
                cfg.subjects    = idata;
                cfg.nsplit      = nsplit;
                decode_transfer_from_sensors(cfg);
            end 

            load(transfer_file('evidence',idata,icond_trn,icond_tst), 'out_dec', 'tim')
            zdec_evidence_transfer(idata, :, ipair) = r2z(out_dec.rdec);
        end
        % load within (same folds and test trials as the transfer)
        for icond = 1:2
            if ~exist([transfer_file('pitch',idata,icond,icond) '.mat'],'file')
                cfg = [];
                cfg.reg         = 'pitch';
                cfg.across      = 'condition';
                cfg.sound       = isound;
                cfg.subjects    = idata;
                cfg.nsplit      = nsplit;
                decode_transfer_from_sensors(cfg);
            end 
            load(transfer_file('pitch',idata,icond,icond), 'out_dec')
            zdec_pitch(idata,:,icond) = r2z(out_dec.rdec);

            if ~exist([transfer_file('evidence',idata,icond,icond) '.mat'],'file')
                cfg = [];
                cfg.reg         = 'evidence';
                cfg.across      = 'condition';
                cfg.sound       = isound;
                cfg.subjects    = idata;
                cfg.nsplit      = nsplit;
                decode_transfer_from_sensors(cfg);
            end
            load(transfer_file('evidence',idata,icond,icond), 'out_dec', 'tim')
            zdec_evidence(idata,:,icond) = r2z(out_dec.rdec);
        end
        fprintf('done.\n')
    end
end

% zdec_transfer(:,:,1) = tracking >> listen
% zdec_transfer(:,:,2) = listen >> tracking


%% MAIN Fig. 4b (SUPP Fig. 6a): mean decoding t > 0, within vs transfer for each test condition
for icond = 1:2
    cfg = cfg_fig;
    if isound == 1
        cfg.figname = sprintf('fig4b_within_transfer_pitch_tested_on%s%s',condname{icond},soundname{isound});
    else
        cfg.figname = sprintf('SUPP_fig6a_within_transfer_pitch_tested_on%s%s',condname{icond},soundname{isound});
    end
    cfg.x = cat(2,mean(zdec_pitch(idata2keep,tim>0,icond),2),mean(zdec_pitch_transfer(idata2keep,tim>0,3-icond),2));
    cfg.plotx = true;
    cfg.ttest = true;
    cfg.tail = 'right'; % within > transfer
    cfg.rgb = [rgb_pitch(icond,:);(1+rgb_pitch(icond,:))/2];
    if isound == 2
        cfg.rgb = (1+cfg.rgb)/2;
    end
    cfg.pbar = 0.7;
    cfg.ytick = 0:.1:.2;
    cfg.ylim = [0 0.2];
    cfg.xlabel = soundname{isound}(2:end);
    cfg.xticklabel = {'within','transfer'};
    cfg.ylabel = 'mean decoding (z)';
    helper_plot_overall_bars(cfg)
    [~,pval] = ttest(cfg.x(:,1),cfg.x(:,2),'tail','right');
    fprintf('pitch within cond%d > pitch trained on cond%d transfered on cond %d (one-tail ttest)? : pval = %4.3f\n',icond,3-icond,icond,pval)

    cfg = cfg_fig;
    if isound == 1
        cfg.figname = sprintf('fig4b_within_transfer_evidence_tested_on%s%s',condname{icond},soundname{isound});
    else
        cfg.figname = sprintf('SUPP_fig6a_within_transfer_evidence_tested_on%s%s',condname{icond},soundname{isound});
    end
    cfg.x = cat(2,mean(zdec_evidence(idata2keep,tim>0,icond),2),mean(zdec_evidence_transfer(idata2keep,tim>0,3-icond),2));
    cfg.plotx = true;
    cfg.ttest = true;
    cfg.tail = 'right'; % within > transfer
    cfg.rgb = [rgb_evidence(icond,:);(1+rgb_evidence(icond,:))/2];
    if isound == 2
        cfg.rgb = (1+cfg.rgb)/2;
    end
    cfg.pbar = 0.7;
    cfg.ytick = 0:.1:.3;
    cfg.ylim = [0 0.25];
    cfg.xlabel = soundname{isound}(2:end);
    cfg.xticklabel = {'within','transfer'};
    cfg.ylabel = 'mean decoding (z)';
    helper_plot_overall_bars(cfg)
    [~,pval] = ttest(cfg.x(:,1),cfg.x(:,2),'tail','right');
    fprintf('evidence within cond%d > evidence trained on cond%d transfered on cond %d (one-tail ttest)? : pval = %4.3f\n',icond,3-icond,icond,pval)
end

%% MAIN Fig. 4b (SUPP Fig. 6a): all 4 on one plot
cfg = cfg_fig;
if isound == 1
    cfg.figname = sprintf('fig4b_cross_condition_pitch%s',soundname{isound});
else
    cfg.figname = sprintf('SUPP_fig6a_cross_condition_pitch%s',soundname{isound});
end
cfg.x = cat(2,mean(zdec_pitch(idata2keep,tim>0,1),2),mean(zdec_pitch_transfer(idata2keep,tim>0,2),2),mean(zdec_pitch(idata2keep,tim>0,2),2),mean(zdec_pitch_transfer(idata2keep,tim>0,1),2));
cfg.plotx = true;
cfg.ttest = true;
cfg.rgb = [rgb_pitch(1,:);(1+rgb_pitch(1,:))/2;rgb_pitch(2,:);(1+rgb_pitch(2,:))/2];
if isound == 2
    cfg.rgb = (1+cfg.rgb)/2;
end
cfg.pbar = 1.2;
cfg.ytick = 0:.1:.2;
cfg.ylim = [0 0.2];
cfg.xlabel = soundname{isound}(2:end);
cfg.xticklabel = {'within','transfer','within','transfer'};
cfg.ylabel = 'mean decoding (z)';
helper_plot_overall_bars(cfg)

cfg = cfg_fig;
if isound == 1
    cfg.figname = sprintf('fig4b_cross_condition_evidence%s',soundname{isound});
else
    cfg.figname = sprintf('SUPP_fig6a_cross_condition_evidence%s',soundname{isound});
end
cfg.x = cat(2,mean(zdec_evidence(idata2keep,tim>0,1),2),mean(zdec_evidence_transfer(idata2keep,tim>0,2),2),mean(zdec_evidence(idata2keep,tim>0,2),2),mean(zdec_evidence_transfer(idata2keep,tim>0,1),2));
cfg.plotx = true;
cfg.ttest = true;
cfg.rgb = [rgb_evidence(1,:);(1+rgb_evidence(1,:))/2;rgb_evidence(2,:);(1+rgb_evidence(2,:))/2];
if isound == 2
    cfg.rgb = (1+cfg.rgb)/2;
end
cfg.pbar = 1.2;
cfg.ytick = 0:.1:.2;
cfg.ylim = [0 0.25];
cfg.xlabel = soundname{isound}(2:end);
cfg.xticklabel = {'within','transfer','within','transfer'};
cfg.ylabel = 'mean decoding (z)';
helper_plot_overall_bars(cfg)

%% MAIN Fig. 4b (SUPP Fig. 6a), Results text: PITCH, train x test ANOVA and post-hoc tests
zdec_within = zdec_pitch;
zdec_transfer = zdec_pitch_transfer;

% TAP trained, TAP tested (within TAP)
x1 = mean(zdec_within(idata2keep,tim>0,1),2);
% LIS trained, TAP tested (transfer to TAP)
x2 = mean(zdec_transfer(idata2keep,tim>0,2),2);
% TAP trained, LIS tested (transfer to LIS)
x3 = mean(zdec_transfer(idata2keep,tim>0,1),2);
% LIS trained, LIS tested (within LIS)
x4 = mean(zdec_within(idata2keep,tim>0,2),2);
% dim2: train
% dim3: test
x = cat(3,[x1 x2],[x3 x4]);

anova_2x2_ttest(x,{'train','test'},'pitch, mean decoding t > 0');

fprintf('post-hoc ttest (one-tail):\n')
[~,pval,~,stats]=ttest(x1,x3,'tail','right');
fprintf('train(TAP)/test(TAP) > train(TAP)/test(LIS) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)
[~,pval,~,stats]=ttest(x1,x2,'tail','right');
fprintf('train(TAP)/test(TAP) > train(LIS)/test(TAP) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)

[~,pval,~,stats]=ttest(x4,x2,'tail','right');
fprintf('train(LIS)/test(LIS) > train(LIS)/test(TAP) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)
[~,pval,~,stats]=ttest(x4,x3,'tail','right');
fprintf('train(LIS)/test(LIS) > train(TAP)/test(LIS) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)

%% MAIN Fig. 4b (SUPP Fig. 6a), Results text: EVIDENCE, train x test ANOVA and post-hoc tests
zdec_within = zdec_evidence;
zdec_transfer = zdec_evidence_transfer;

% TAP trained, TAP tested (within TAP)
x1 = mean(zdec_within(idata2keep,tim>0,1),2);
% LIS trained, TAP tested (transfer to TAP)
x2 = mean(zdec_transfer(idata2keep,tim>0,2),2);
% TAP trained, LIS tested (transfer to LIS)
x3 = mean(zdec_transfer(idata2keep,tim>0,1),2);
% LIS trained, LIS tested (within LIS)
x4 = mean(zdec_within(idata2keep,tim>0,2),2);
% dim2: train
% dim3: test
x = cat(3,[x1 x2],[x3 x4]);
anova_2x2_ttest(x,{'train','test'},'evidence, mean decoding t > 0');

fprintf('post-hoc ttest (one-tail):\n')
[~,pval,~,stats]=ttest(x1,x3,'tail','right');
fprintf('train(TAP)/test(TAP) > train(TAP)/test(LIS) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)
[~,pval,~,stats]=ttest(x1,x2,'tail','right');
fprintf('train(TAP)/test(TAP) > train(LIS)/test(TAP) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)

[~,pval,~,stats]=ttest(x4,x2,'tail','right');
fprintf('train(LIS)/test(LIS) > train(LIS)/test(TAP) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)
[~,pval,~,stats]=ttest(x4,x3,'tail','right');
fprintf('train(LIS)/test(LIS) > train(TAP)/test(LIS) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)

%% MAIN Fig. 4c (evidence tested on tracking): time courses when trained and tested on the same condition, or trained on the other condition
for icond = 1:2
    cfg = cfg_fig;
    if isound == 1
        cfg.figname = sprintf('fig4c_decoding_within_transfer_pitch_tested_on%s%s',condname{icond},soundname{isound});
    else
        cfg.figname = sprintf('SUPP_fig6a_decoding_within_transfer_pitch_tested_on%s%s',condname{icond},soundname{isound});
    end
    cfg.zdec = cat(3,zdec_pitch(idata2keep,:,icond),zdec_pitch_transfer(idata2keep,:,3-icond));
    cfg.xvec = tim;
    cfg.statsbetween = true;
    cfg.ylim = [-0.08 0.4]/2;
    cfg.rgb = [rgb_pitch(icond,:);(1+rgb_pitch(icond,:))/2];
    helper_plot_decoding(cfg);

    cfg = cfg_fig;
    if isound == 1
        cfg.figname = sprintf('fig4c_decoding_within_transfer_evidence_tested_on%s%s',condname{icond},soundname{isound});
    else
        cfg.figname = sprintf('SUPP_fig6a_decoding_within_transfer_evidence_tested_on%s%s',condname{icond},soundname{isound});
    end
    cfg.zdec = cat(3,zdec_evidence(idata2keep,:,icond),zdec_evidence_transfer(idata2keep,:,3-icond));
    cfg.xvec = tim;
    cfg.statsbetween = true;
    cfg.ylim = [-0.08 0.4];
    cfg.rgb = [rgb_evidence(icond,:);(1+rgb_evidence(icond,:))/2];
    helper_plot_decoding(cfg);
end


%% PART 2: Fig. 4d and Supp. Fig. 6b, carry-over
% compare conditions! not soundtypes!
% targets for main, distractors for supp
% decode the pitch and evidence of the previous tone of the same type
% (pitch_lag2, evidence_lag2: 2 positions before) around the onset of the next one

clearvars
close all
clc

isound = 1; %1 = targets (Fig. 4d), 2 = distractors (Supp. Fig. 6b)

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
condname = {'_tracking', '_listen'};
soundname = {'_tar', '_dis'};
nextname = {'next target', 'next DIS'};
ylab = sprintf('mean decoding\naround %s',nextname{isound});
r2z = @(r)0.5*log((1+r)./(1-r)); % fisher z transform
figpath = paths.fig_dir;

cfg_fig = [];
cfg_fig.figpath = figpath;
cfg_fig.saveornot = saveornot;

load(paths.table,'data')

zdec_pitch = nan(ndata,301,2);
zdec_pitch_corerr = nan(ndata,301,2,2);
zdec_evidence  = nan(ndata,301,2);
zdec_evidence_corerr = nan(ndata,301,2,2);

fprintf('Loading decoding results for \n')
for idata = 1:ndata
    fprintf('\tsubject %02d/%02d...',idata,ndata)
    if ~ismember(idata,idata2keep)
        fprintf('done.\n')
        continue
    else
        for icond = 1:2
            % pitch of the previous tone of the same type
            reg = 'pitch_lag2';
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

            % cor/err
            ifilt = subdat.iscor;
            zdec_pitch_corerr(idata,:,icond,1) = zdec_filtered(out_dec.Chat,out_dec.Ctru,ifilt);
            zdec_pitch_corerr(idata,:,icond,2) = zdec_filtered(out_dec.Chat,out_dec.Ctru,~ifilt);

            % evidence of the previous tone of the same type
            reg = 'evidence_lag2';
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
            % cor/err
            ifilt = subdat.iscor;
            zdec_evidence_corerr(idata,:,icond,1) = zdec_filtered(out_dec.Chat,out_dec.Ctru,ifilt);
            zdec_evidence_corerr(idata,:,icond,2) = zdec_filtered(out_dec.Chat,out_dec.Ctru,~ifilt);
        end
    end
    fprintf('done.\n')
end

xvec = tim;


%% MAIN Fig. 4d (SUPP Fig. 6b): carry-over, mean decoding around the next tone, tracking vs listen
ifilt = tim>-0.1923 & tim<0.1923; % around the onset of the next tone of the same type

cfg = cfg_fig;
if isound == 1
    cfg.figname = sprintf('fig4d_carry_over_listen_tracking_pitch%s',soundname{isound});
else
    cfg.figname = sprintf('SUPP_fig6b_carry_over_listen_tracking_pitch%s',soundname{isound});
end
cfg.x = squeeze(mean(zdec_pitch(idata2keep,ifilt,[2 1]),2)); % listen, tracking
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
cfg.ylabel = ylab;
cfg.ylim = [0 0.2];
cfg.xlabel = soundname{isound}(2:end);
cfg.xticklabel = {'listen' 'tracking'};
helper_plot_overall_bars(cfg)

[~,p,~,stats]=ttest(cfg.x,0,'tail','right');
for icol = 1:2
fprintf('%s pitch_lag2 against 0 (one-tail ttest): pval = %4.4f, t = %4.4f\n',upper(condname{3-icol}(2:end)),p(icol),stats.tstat(icol));
end
[~,pval,~,stats] = ttest(cfg.x(:,2),cfg.x(:,1),'tail','right'); % tracking > listen
bf10 = bf.ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
fprintf('pitch_lag2(TAP) > pitch_lag2(LIS) (one-tail ttest)? : pval = %4.3f; t=%4.3f; bf10 = %4.3f\n',pval,stats.tstat,bf10)

cfg = cfg_fig;
if isound == 1
    cfg.figname = sprintf('fig4d_carry_over_listen_tracking_evidence%s',soundname{isound});
else
    cfg.figname = sprintf('SUPP_fig6b_carry_over_listen_tracking_evidence%s',soundname{isound});
end
cfg.x = squeeze(mean(zdec_evidence(idata2keep,ifilt,[2 1]),2)); % listen, tracking
cfg.plotx = true;
cfg.ttest = true;
cfg.tail = 'left'; % listen < tracking
if isound == 1
    cfg.rgb = flipud(rgb_evidence);
else
    cfg.rgb = flipud((1+rgb_evidence)/2);
end
cfg.pbar = 0.7;
cfg.ytick = 0:.1:.2;
cfg.ylim = [0 0.2];
cfg.ylabel = ylab;
cfg.xlabel = soundname{isound}(2:end);
cfg.xticklabel = {'listen' 'tracking'};
helper_plot_overall_bars(cfg)
[h,p,ci,stats]=ttest(cfg.x,0,'tail','right');
for icol = 1:2
fprintf('%s evidence_lag2 against 0 (one-tail ttest): pval = %4.4f, t = %4.4f\n',upper(condname{3-icol}(2:end)),p(icol),stats.tstat(icol));
end
[~,pval,~,stats] = ttest(cfg.x(:,2),cfg.x(:,1),'tail','right'); % tracking > listen
bf10 = bf.ttest(cfg.x(:,2),cfg.x(:,1),'tail','right');
fprintf('evidence_lag2(TAP) > evidence_lag2(LIS) (one-tail ttest)? : pval = %4.3f; t=%4.3f; bf10 = %4.3f\n',pval,stats.tstat,bf10)


%% PART 3: Supp. Fig. 5, signal-to-noise control
% control of the transfer between conditions (decode_transfer_control): the trials
% of one condition (tracking by default) are split into two halves, noise estimated
% from the other condition is added, and the decoder is trained and tested within and
% across halves, with and without noise

clearvars
close all
clc

paths = config_paths();

isound = 1; % 1 = targets, 2 = distractors
icond = 1;  % condition split into halves: 1 = tracking, 2 = listen (the noise comes from the other condition)

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

rgb_evidence = [rgb_tap(2,:);rgb_lis(2,:)];

saveornot = false;

flowpass = 8;
nsplit = 10; % decoding averaged over nsplit random splits of the trials into folds (1 = single split)
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

zdec_dir = paths.results_dir;

% Load control results
rdec_ctrl = nan(ndata, 10); % 10 configs per subject
% Config order:
% 1: within half1 no noise
% 2: within half2 no noise
% 3: within half1 noisy
% 4: within half2 noisy
% 5: transfer h1->h2 no noise
% 6: transfer h2->h1 no noise
% 7: transfer h1->h2 with noise (on h2)
% 8: transfer h1 noisy->h2
% 9: transfer h2->h1 with noise (on h1)
% 10: transfer h2 noisy->h1

reg = 'evidence';
noise_level = 1;
for idata = 1:ndata
    if ~ismember(idata, idata2keep)
        continue
    end
    fname = fullfile(zdec_dir, reg, sprintf(... 
        'transfer_ctrl_splithalf_%s_%dhz_idata%d_ridge_alpha_500%s%s_noise-white-%.2f%s',...
        reg, flowpass, idata, condname{icond}, upper(soundname{isound}), noise_level, splittag));
    if ~exist([fname '.mat'],'file')
        cfg = [];
        cfg.reg         = reg;
        cfg.cond        = icond;
        cfg.sound       = isound;
        cfg.noise_level = noise_level;
        cfg.subjects    = idata;
        cfg.nsplit      = nsplit;
        decode_transfer_control(cfg);
    end
    load(fname, 'out_dec_ctrl', 'tim');

    % Extract all 10 scenarios: mean decoding precision (Fisher z) over t>0, as in the figures
    rdec_ctrl(idata, 1)  = mean(out_dec_ctrl.zdec_within_h1(tim>0));
    rdec_ctrl(idata, 2)  = mean(out_dec_ctrl.zdec_within_h2(tim>0));
    rdec_ctrl(idata, 3)  = mean(out_dec_ctrl.zdec_within_h1_noisy(tim>0));
    rdec_ctrl(idata, 4)  = mean(out_dec_ctrl.zdec_within_h2_noisy(tim>0));
    rdec_ctrl(idata, 5)  = mean(out_dec_ctrl.zdec_transfer_h1_h2(tim>0));
    rdec_ctrl(idata, 6)  = mean(out_dec_ctrl.zdec_transfer_h2_h1(tim>0));
    rdec_ctrl(idata, 7)  = mean(out_dec_ctrl.zdec_transfer_h1_h2_noisy(tim>0));
    rdec_ctrl(idata, 8)  = mean(out_dec_ctrl.zdec_transfer_h1_noisy_h2(tim>0));
    rdec_ctrl(idata, 9)  = mean(out_dec_ctrl.zdec_transfer_h2_h1_noisy(tim>0));
    rdec_ctrl(idata, 10) = mean(out_dec_ctrl.zdec_transfer_h2_noisy_h1(tim>0));
end
rdec_ctrl = rdec_ctrl(idata2keep, :);

w_h1          = rdec_ctrl(:, 1);  % within half1 no noise
w_h2          = rdec_ctrl(:, 2);  % within half2 no noise
w_h1_noisy    = rdec_ctrl(:, 3);  % within half1 noisy
w_h2_noisy    = rdec_ctrl(:, 4);  % within half2 noisy

t_h1_h2       = rdec_ctrl(:, 5);  % transfer h1->h2 no noise
t_h2_h1       = rdec_ctrl(:, 6);  % transfer h2->h1 no noise

t_h1_h2_noisy = rdec_ctrl(:, 7);  % transfer h1->h2 with noise (on h2)
t_h2_h1_noisy = rdec_ctrl(:, 9);  % transfer h2->h1 with noise (on h1)

t_h1_noisy_h2 = rdec_ctrl(:, 8);  % transfer h1 noisy->h2
t_h2_noisy_h1 = rdec_ctrl(:, 10); % transfer h2 noisy->h1

% Average between directions to make it independent of halves
within_clean = mean([w_h1, w_h2], 2);                % Average within (clean)
within_noisy = mean([w_h1_noisy, w_h2_noisy], 2);      % Average within (noisy)

transfer_clean = mean([t_h1_h2, t_h2_h1], 2);          % Average transfer (clean)

% Noise on test half only
transfer_noisy_on_test = mean([t_h1_h2_noisy, t_h2_h1_noisy], 2);

% Noise on train half only
transfer_noisy_on_train = mean([t_h1_noisy_h2, t_h2_noisy_h1], 2);

% SUPP Fig. 5a (noise_level = 0.5) or 5b (noise_level = 1): within versus transfer, for each test half
x1 = within_clean; % TAP trained, TAP tested (within TAP)
x2 = transfer_noisy_on_train; % LIS (i.e. noisy TAP) trained, TAP tested (transfer to TAP)
x3 = transfer_noisy_on_test ; % TAP trained, LIS (i.e. noisy TAP) tested (transfer to LIS (i.e. noisy TAP))
x4 = within_noisy; % LIS (i.e. noisy TAP) trained, LIS (i.e. noisy TAP) tested (within LIS (i.e. noisy TAP))

% tested on the clean half (tracking): within vs trained on the noisy half
cfg = cfg_fig;
cfg.figname = sprintf('SUPP_fig5_within_transfer_evidence_tested_on_clean%s%s_noise-white-%.2f',condname{icond},soundname{isound},noise_level);
cfg.x = cat(2,x1,x2);
cfg.plotx = true;
cfg.ttest = true;
cfg.tail = 'right'; % within > transfer
cfg.rgb = [rgb_evidence(1,:);(1+rgb_evidence(1,:))/2];
cfg.pbar = 0.7;
cfg.ytick = 0:.1:.2;
cfg.ylim = [0 0.25];
cfg.xlabel = soundname{isound}(2:end);
cfg.xticklabel = {'within','transfer'};
cfg.ylabel = 'mean decoding (z)';
helper_plot_overall_bars(cfg)

% tested on the noisy half (lower SNR): within vs trained on the clean half
cfg = cfg_fig;
cfg.figname = sprintf('SUPP_fig5_within_transfer_evidence_tested_on_noisy%s%s_noise-white-%.2f',condname{icond},soundname{isound},noise_level);
cfg.x = cat(2,x4,x3);
cfg.plotx = true;
cfg.ttest = true;
cfg.tail = 'right'; % within > transfer
cfg.rgb = [rgb_evidence(2,:);(1+rgb_evidence(2,:))/2];
cfg.pbar = 0.7;
cfg.ytick = 0:.1:.2;
cfg.ylim = [0 0.25];
cfg.xlabel = soundname{isound}(2:end);
cfg.xticklabel = {'within','transfer'};
cfg.ylabel = 'mean decoding (z)';
helper_plot_overall_bars(cfg)

x = cat(3,[x1 x2],[x3 x4]);
anova_2x2_ttest(x,{'train','test'},sprintf('%s, split-half control (white noise %.2f), mean decoding t > 0',reg,noise_level));

fprintf('post-hoc ttest (one-tail):\n')
[~,pval,~,stats]=ttest(x1,x3,'tail','right');
fprintf('train(TAP)/test(TAP) > train(TAP)/test(LIS (i.e. noisy TAP)) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)
[~,pval,~,stats]=ttest(x1,x2,'tail','right');
fprintf('train(TAP)/test(TAP) > train(LIS (i.e. noisy TAP))/test(TAP) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)

[~,pval,~,stats]=ttest(x4,x2,'tail','right');
fprintf('train(LIS (i.e. noisy TAP))/test(LIS (i.e. noisy TAP)) > train(LIS (i.e. noisy TAP))/test(TAP) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)
[~,pval,~,stats]=ttest(x4,x3,'tail','right');
fprintf('train(LIS (i.e. noisy TAP))/test(LIS (i.e. noisy TAP)) > train(TAP)/test(LIS (i.e. noisy TAP)) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)

fprintf('split-half control (white noise %.2f), %s, mean decoding t > 0:\n',noise_level,reg);
% without noise, decoders trained on either half perform equally (both directions averaged)
[~,pval,~,stats] = ttest(within_clean,transfer_clean); % two-tailed
fprintf('\tno noise, within vs transfer (two-tailed ttest): pval = %4.4f; t = %4.4f\n',pval,stats.tstat)
% drop of the decoding accuracy with the added noise
fprintf('\tdrop of the within decoding with noise: %.1f %%\n',100*(1 - mean(within_noisy)/mean(within_clean)))
% for comparison, drop of the decoding in the other condition (the source of the noise),
% from the decodings of each condition (decode_from_sensors, as in Fig. 3a)
zdec_cond = nan(ndata2keep,2);
for k = 1:ndata2keep
    for jcond = 1:2
        fname = fullfile(zdec_dir,reg,sprintf('out_dec_%s_%dhz_idata%d_ridge_alpha_500%s%s_eq-none%s',reg,flowpass,idata2keep(k),condname{jcond},upper(soundname{isound}),splittag));
        if ~exist([fname '.mat'],'file')
            cfg = [];
            cfg.reg         = reg;
            cfg.subjects    = idata2keep(k);
            cfg.cond        = jcond;
            cfg.sound       = isound;
            cfg.equalize    = 'none';
            cfg.nsplit      = nsplit;
            decode_from_sensors(cfg);
        end
        S = load(fname,'out_dec','tim');
        zdec_cond(k,jcond) = mean(r2z(S.out_dec.rdec(S.tim>0)));
    end
end
fprintf('\tdrop of the decoding in %s compared to %s: %.1f %%\n',condname{3-icond}(2:end),condname{icond}(2:end), ...
    100*(1 - mean(zdec_cond(:,3-icond))/mean(zdec_cond(:,icond))))


%% PART 4: Supp. Fig. 7, cross-sound-type decoding
% compare soundtypes! not conditions!
% transfer between soundtypes (decode_transfer_from_sensors, cfg.across = 'soundtype',
% targets and distractors equalized on dfq): within (trained and tested on the same
% soundtype) and transfer (trained on the other soundtype) are computed with the same
% folds and tested on the same trials

clearvars
close all
clc

paths = config_paths();

icond = 1; % 1 = tracking, 2 = listen
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

rgb_pitch = [rgb_tap(1,:);rgb_lis(1,:)];
rgb_evidence = [rgb_tap(2,:);rgb_lis(2,:)];

flowpass = 8;
nsplit = 10; % decoding averaged over nsplit random splits of the trials into folds (1 = single split)
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

zdec_dir = paths.results_dir;
% file of the decoder trained on soundtype isound_trn and tested on soundtype isound_tst
transfer_file = @(reg,idata,isound_trn,isound_tst) fullfile(zdec_dir,reg,sprintf('transfer_out_dec_%s_%dhz_idata%d_ridge_alpha_500_TRN%s_TST%s%s_eq-soundtype%s', ...
    reg,flowpass,idata,soundname{isound_trn},soundname{isound_tst},upper(condname{icond}),splittag));

% initialize
zdec_pitch = nan(ndata,301,2);             % within, last dim = soundtype
zdec_evidence = nan(ndata,301,2);
zdec_pitch_transfer = nan(ndata, 301, 2);  % last dim = direction
zdec_evidence_transfer = nan(ndata, 301, 2);

transfer_pairs = [1 2; 2 1];
fprintf('Loading decoding results for \n')
for idata = 1:ndata
    fprintf('\tsubject %02d/%02d...',idata,ndata)
    if ~ismember(idata,idata2keep)
        fprintf('not used.\n')
        continue
    else
        % load transfer
        for ipair = 1:2
            isound_trn = transfer_pairs(ipair, 1);
            isound_tst = transfer_pairs(ipair, 2);
            if ~exist([transfer_file('pitch',idata,isound_trn,isound_tst) '.mat'],'file')
                cfg = [];
                cfg.reg         = 'pitch';
                cfg.across      = 'soundtype';
                cfg.cond        = icond;
                cfg.subjects    = idata;
                cfg.nsplit      = nsplit;
                decode_transfer_from_sensors(cfg);
            end
            load(transfer_file('pitch',idata,isound_trn,isound_tst), 'out_dec')
            zdec_pitch_transfer(idata, :, ipair) = r2z(out_dec.rdec);

            if ~exist([transfer_file('evidence',idata,isound_trn,isound_tst) '.mat'],'file')
                cfg = [];
                cfg.reg         = 'evidence';
                cfg.across      = 'soundtype';
                cfg.cond        = icond;
                cfg.subjects    = idata;
                cfg.nsplit      = nsplit;
                decode_transfer_from_sensors(cfg);
            end

            load(transfer_file('evidence',idata,isound_trn,isound_tst), 'out_dec', 'tim')
            zdec_evidence_transfer(idata, :, ipair) = r2z(out_dec.rdec);
        end
        % load within (same folds and test trials as the transfer)
        for isound = 1:2
            if ~exist([transfer_file('pitch',idata,isound,isound) '.mat'],'file')
                cfg = [];
                cfg.reg         = 'pitch';
                cfg.across      = 'soundtype';
                cfg.cond        = icond;
                cfg.subjects    = idata;
                cfg.nsplit      = nsplit;
                decode_transfer_from_sensors(cfg);
            end
            load(transfer_file('pitch',idata,isound,isound), 'out_dec')
            zdec_pitch(idata,:,isound) = r2z(out_dec.rdec);

            if ~exist([transfer_file('evidence',idata,isound,isound) '.mat'],'file')
                cfg = []; 
                cfg.reg         = 'evidence';
                cfg.across      = 'soundtype';
                cfg.cond        = icond;
                cfg.subjects    = idata;
                cfg.nsplit      = nsplit;
                decode_transfer_from_sensors(cfg);
            end
            load(transfer_file('evidence',idata,isound,isound), 'out_dec', 'tim')
            zdec_evidence(idata,:,isound) = r2z(out_dec.rdec);
        end
        fprintf('done.\n')
    end
end
% zdec_transfer(:,:,1) = targets >> distractors
% zdec_transfer(:,:,2) = distractors >> targets

%% SUPP Fig. 7a,b: mean decoding t > 0, within vs transfer for each test soundtype
for isound = 1:2
    cfg = cfg_fig;
    cfg.figname = sprintf('SUPP_fig7a_within_transfer_pitch%s_tested_on%s',condname{icond},soundname{isound});
    cfg.x = cat(2,mean(zdec_pitch(idata2keep,tim>0,isound),2),mean(zdec_pitch_transfer(idata2keep,tim>0,3-isound),2));
    cfg.plotx = true;
    cfg.ttest = true;
    cfg.tail = 'right'; % within > transfer
    if isound == 1
        cfg.rgb = [rgb_pitch(icond,:);(1+rgb_pitch(icond,:))/2];
    else
        cfg.rgb = [(1+rgb_pitch(icond,:))/2;(1+(1+rgb_pitch(icond,:))/2)/2];
    end
    cfg.pbar = 0.7;
    cfg.ytick = 0:.1:.2;
    cfg.ylim = [0 0.2];
    cfg.xlabel = soundname{isound}(2:end);
    cfg.xticklabel = {'within','transfer'};
    cfg.ylabel = 'mean decoding (z)';
    helper_plot_overall_bars(cfg)
    [~,pval] = ttest(cfg.x(:,1),cfg.x(:,2),'tail','right');
    fprintf('cond%d: pitch within sound%d > pitch trained on sound%d transfered on sound %d (one-tail ttest)? : pval=%4.4f\n',icond,isound,3-isound,isound,pval)

    cfg = cfg_fig;
    cfg.figname = sprintf('SUPP_fig7b_within_transfer_evidence%s_tested_on%s',condname{icond},soundname{isound});
    cfg.x = cat(2,mean(zdec_evidence(idata2keep,tim>0,isound),2),mean(zdec_evidence_transfer(idata2keep,tim>0,3-isound),2));
    cfg.plotx = true;
    cfg.ttest = true;
    cfg.tail = 'right'; % within > transfer
    if isound == 1
        cfg.rgb = [rgb_evidence(icond,:);(1+rgb_evidence(icond,:))/2];
    else
        cfg.rgb = [(1+rgb_evidence(icond,:))/2;(1+(1+rgb_evidence(icond,:))/2)/2];
    end
    cfg.pbar = 0.7;
    cfg.ytick = 0:.1:.3;
    cfg.ylim = [0 0.3];
    cfg.xlabel = condname{icond}(2:end);
    cfg.xticklabel = {'within','transfer'};
    cfg.ylabel = 'mean decoding (z)';
    helper_plot_overall_bars(cfg)
    [~,pval] = ttest(cfg.x(:,1),cfg.x(:,2),'tail','right');
    fprintf('cond%d: evidence within sound %d > evidence trained on sound %d transfered on sound %d (one-tail ttest)? : pval = %4.4f\n',icond, isound,3-isound,isound,pval)
end

%% SUPP Fig. 7a,b: all 4 on one plot
cfg = cfg_fig;
cfg.figname = sprintf('SUPP_fig7a_cross_soundtype_pitch%s',condname{icond});
cfg.x = cat(2,mean(zdec_pitch(idata2keep,tim>0,1),2),mean(zdec_pitch_transfer(idata2keep,tim>0,2),2),mean(zdec_pitch(idata2keep,tim>0,2),2),mean(zdec_pitch_transfer(idata2keep,tim>0,1),2));
cfg.plotx = true;
cfg.ttest = true;
cfg.rgb = [rgb_pitch(icond,:);rgb_pitch(icond,:);(1+rgb_pitch(icond,:))/2;(1+rgb_pitch(icond,:))/2];
cfg.pbar = 1.2;
cfg.ytick = 0:.1:.2;
cfg.ylim = [0 0.2];
cfg.xlabel = condname{icond}(2:end);
cfg.xticklabel = {'within','transfer','within','transfer'};
cfg.ylabel = 'mean decoding (z)';
helper_plot_overall_bars(cfg)

cfg = cfg_fig;
cfg.figname = sprintf('SUPP_fig7b_cross_soundtype_evidence%s',condname{icond});
cfg.x = cat(2,mean(zdec_evidence(idata2keep,tim>0,1),2),mean(zdec_evidence_transfer(idata2keep,tim>0,2),2),mean(zdec_evidence(idata2keep,tim>0,2),2),mean(zdec_evidence_transfer(idata2keep,tim>0,1),2));
cfg.plotx = true;
cfg.ttest = true;
cfg.rgb = [rgb_evidence(icond,:);rgb_evidence(icond,:);(1+rgb_evidence(icond,:))/2;(1+rgb_evidence(icond,:))/2];
cfg.pbar = 1.2;
cfg.ytick = 0:.1:.2;
cfg.ylim = [0 0.2];
cfg.xlabel = condname{icond}(2:end);
cfg.xticklabel = {'within','transfer','within','transfer'};
cfg.ylabel = 'mean decoding (z)';
helper_plot_overall_bars(cfg)

%% SUPP Fig. 7a, Results text: PITCH, train x test ANOVA and post-hoc tests
zdec_within = zdec_pitch;
zdec_transfer = zdec_pitch_transfer;

% TAR trained, TAR tested (within TAR)
x1 = mean(zdec_within(idata2keep,tim>0,1),2);
% DIS trained, TAR tested (transfer to TAR)
x2 = mean(zdec_transfer(idata2keep,tim>0,2),2);
% TAR trained, DIS tested (transfer to DIS)
x3 = mean(zdec_transfer(idata2keep,tim>0,1),2);
% DIS trained, DIS tested (within DIS)
x4 = mean(zdec_within(idata2keep,tim>0,2),2);
% dim2: train
% dim3: test
x = cat(3,[x1 x2],[x3 x4]);
anova_2x2_ttest(x,{'train','test'},sprintf('pitch%s, mean decoding t > 0',condname{icond}));

fprintf('post-hoc ttest (one-tail):\n')
[~,pval,~,stats]=ttest(x1,x3,'tail','right');
fprintf('train(TAR)/test(TAR) > train(TAR)/test(DIS) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)
[~,pval,~,stats]=ttest(x1,x2,'tail','right');
fprintf('train(TAR)/test(TAR) > train(DIS)/test(TAR) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)

[~,pval,~,stats]=ttest(x4,x2,'tail','right');
fprintf('train(DIS)/test(DIS) > train(DIS)/test(TAR) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)
[~,pval,~,stats]=ttest(x4,x3,'tail','right');
fprintf('train(DIS)/test(DIS) > train(TAR)/test(DIS) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)

%% SUPP Fig. 7b, Results text: EVIDENCE, train x test ANOVA and post-hoc tests
zdec_within = zdec_evidence;
zdec_transfer = zdec_evidence_transfer;

% TAR trained, TAR tested (within TAR)
x1 = mean(zdec_within(idata2keep,tim>0,1),2);
% DIS trained, TAR tested (transfer to TAR)
x2 = mean(zdec_transfer(idata2keep,tim>0,2),2);
% TAR trained, DIS tested (transfer to DIS)
x3 = mean(zdec_transfer(idata2keep,tim>0,1),2);
% DIS trained, DIS tested (within DIS)
x4 = mean(zdec_within(idata2keep,tim>0,2),2);
% dim2: train
% dim3: test
x = cat(3,[x1 x2],[x3 x4]);
anova_2x2_ttest(x,{'train','test'},sprintf('evidence%s, mean decoding t > 0',condname{icond}));

fprintf('post-hoc ttest (one-tail):\n')
[~,pval,~,stats]=ttest(x1,x3,'tail','right');
fprintf('train(TAR)/test(TAR) > train(TAR)/test(DIS) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)
[~,pval,~,stats]=ttest(x1,x2,'tail','right');
fprintf('train(TAR)/test(TAR) > train(DIS)/test(TAR) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)

[~,pval,~,stats]=ttest(x4,x2,'tail','right');
fprintf('train(DIS)/test(DIS) > train(DIS)/test(TAR) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)
[~,pval,~,stats]=ttest(x4,x3,'tail','right');
fprintf('train(DIS)/test(DIS) > train(TAR)/test(DIS) : pval = %4.4f; t=%4.4f\n',pval,stats.tstat)

%% SUPP Fig. 7a,b right (tested on targets, tracking): time courses when trained and tested on the same soundtype or trained on the other soundtype
for isound = 1:2
    cfg = cfg_fig;
    cfg.figname = sprintf('SUPP_fig7a_decoding_within_transfer_pitch%s_tested_on%s',condname{icond},soundname{isound});
    cfg.zdec = cat(3,zdec_pitch(idata2keep,:,isound),zdec_pitch_transfer(idata2keep,:,3-isound));
    cfg.xvec = tim;
    cfg.statsbetween = true;
    cfg.ylim = [-0.04 0.2];
    if isound == 1
        cfg.rgb = [rgb_pitch(icond,:);(1+rgb_pitch(icond,:))/2];
    else
        cfg.rgb = [(1+rgb_pitch(icond,:))/2;(1+(1+rgb_pitch(icond,:))/2)/2];
    end
    helper_plot_decoding(cfg);

    cfg = cfg_fig;
    cfg.figname = sprintf('SUPP_fig7b_decoding_within_transfer_evidence%s_tested_on%s',condname{icond},soundname{isound});
    cfg.zdec = cat(3,zdec_evidence(idata2keep,:,isound),zdec_evidence_transfer(idata2keep,:,3-isound));
    cfg.xvec = tim;
    cfg.statsbetween = true;
    cfg.ylim = [-0.08 0.4];
    if isound == 1
        cfg.rgb = [rgb_evidence(icond,:);(1+rgb_evidence(icond,:))/2];
    else
        cfg.rgb = [(1+rgb_evidence(icond,:))/2;(1+(1+rgb_evidence(icond,:))/2)/2];
    end
    helper_plot_decoding(cfg);
end