%% decode_transfer_control
% Control analysis for the transfer decoding between conditions: are transfer results explained
% by a lower signal-to-noise ratio in one condition?
% The trials of one condition (cfg.cond, tracking by default) are split into two
% halves, noise estimated from the other condition is added to them, and the
% decoder is trained and tested within and across halves, with and without noise.
%
% Noise added to the halves, estimated from the other condition: Gaussian (white) noise
% with the covariance of the baseline (t < 0) of the same soundtype, independent across
% time points.
%
% Saved: out_dec_ctrl with, for each of the 10 decodings, the time-resolved
% decoding precision (1 x ntime, Fisher z) zdec_<decoding>, plus tim and dec_cfg:
%   within_h1, within_h2, within_h1_noisy, within_h2_noisy,
%   transfer_h1_h2, transfer_h2_h1 (no noise), transfer_h1_h2_noisy (noise on the
%   test half), transfer_h1_noisy_h2 (noise on the train half), and the same for h2 -> h1
% With cfg.nsplit > 1, zdec_<decoding> is computed from the decoded values averaged
% over the splits, and zdec_split_<decoding> (nsplit x ntime) gives each split.
%
% cfg fields (only cfg.reg is required):
%   reg           regressor to decode, column of the data table (e.g. 'evidence')
%   sound         soundtype: 1 = target, 2 = distractor           [default: 1]
%   cond          condition split into halves: 1 = tracking, 2 = listen; the
%                 noise comes from the other condition             [default: 1]
%   noise_level   scaling of the added noise                       [default: 1]
%   alpha         ridge regularization parameter                   [default: 500]
%   flowpass      low-pass frequency of the Hilbert data (Hz)      [default: 8]
%                 the Hilbert data are prepared by prepare_meg_data
%   nfold         number of cross-validation folds in each half    [default: 5]
%   nsplit        number of random splits of each half into folds  [default: 1]
%                 the halves and the noise are the same for all splits; split 1 takes
%                 the trials of each half in order, split k > 1 shuffles the trials of
%                 each half with rng(idata*100+k-1,'twister'); the decoded values
%                 are averaged over the splits, as in decode_from_sensors
%   nstart        position in the sequence of the first tone to decode, e.g. 2 = from the
%                 second tone (1 = all tones)                    [default: set from reg]
%   subjects      subjects to decode     [default: all, except those excluded by meg_quality_check]
%   meg_dir       folder of the MEG epochs and header files        [default: config_paths]
%   prep_dir      folder of the prepared MEG data                  [default: config_paths]
%   save_prepared save the prepared MEG data (prepare_meg_data)   [default: true]
%   table         trial table (full path)                          [default: config_paths]
%   out_dir       results are saved in <out_dir>/<reg>/            [default: config_paths]
%
% Output file:
%   <out_dir>/<reg>/transfer_ctrl_splithalf_<reg>_<flowpass>hz_idata<n>_ridge_alpha_<alpha>_<cond>_<SOUND>_noise-white-<level>.mat
%   e.g. transfer_ctrl_splithalf_evidence_8hz_idata1_ridge_alpha_500_tracking_TAR_noise-white-1.00.mat
%   (with _start<n> as in decode_from_sensors, and _nsplit<n> when cfg.nsplit > 1)
%
% Example
%   cfg = []; cfg.reg = 'evidence'; cfg.noise_level = 1;
%   decode_transfer_control(cfg)
function decode_transfer_control(cfg)

% options
if ~isfield(cfg,'reg')
    error('cfg.reg is required!');
end
cfg = set_default(cfg,'sound',1);
cfg = set_default(cfg,'cond',1);
cfg = set_default(cfg,'noise_level',1);
cfg = set_default(cfg,'alpha',500);
cfg = set_default(cfg,'flowpass',8);
cfg.hilbert = true; % Hilbert data (prepare_meg_data)
cfg = set_default(cfg,'nfold',5);
cfg = set_default(cfg,'nsplit',1);
cfg = set_default(cfg,'subjects',[]);
paths = config_paths(); % folders set in config_paths.m (and config_paths_local.m)
cfg = set_default(cfg,'meg_dir',paths.meg_dir);
cfg = set_default(cfg,'prep_dir',paths.prep_dir);
cfg = set_default(cfg,'save_prepared',true);
cfg = set_default(cfg,'table',paths.table); % full path
cfg = set_default(cfg,'out_dir',paths.results_dir);
nstart_reg = default_npos_excl(cfg.reg) + 1; % first tone = number of tones without a value of reg + 1
cfg = set_default(cfg,'nstart',nstart_reg);
cond_noise = 3 - cfg.cond; % noise from the other condition

condname = {'_tracking', '_listen'};
soundname = {'_tar', '_dis'};
if cfg.nstart == nstart_reg
    excltag = '';
else
    excltag = sprintf('_start%d',cfg.nstart);
end
if cfg.nsplit > 1
    excltag = [excltag sprintf('_nsplit%d',cfg.nsplit)];
end

fprintf('Control %s%s%s: split halves, white noise from%s, level %.2f\n', cfg.reg, condname{cfg.cond}, ...
    upper(soundname{cfg.sound}), condname{cond_noise}, cfg.noise_level);

% get data
load(cfg.table,'data')
if isempty(cfg.subjects)
    % all subjects, except those excluded for the quality of their MEG data
    excluded = meg_quality_check(struct('meg_dir',cfg.meg_dir,'table',cfg.table,'results_dir',cfg.out_dir));
    allsubj = unique(data.subject)';
    isexcl = arrayfun(@(s) ismember(unique(data.name(data.subject == s)),excluded), allsubj);
    cfg.subjects = allsubj(~isexcl);
end
cfg.subjects = cfg.subjects(:)';

zdec_dir = fullfile(cfg.out_dir, cfg.reg);
if ~exist(zdec_dir,'dir')
    mkdir(zdec_dir);
end
r2z = @(r) 0.5*log((1+r)./(1-r));
nfold = cfg.nfold;
alpha = cfg.alpha;

%% DECODING
tic
for idata = cfg.subjects
    fprintf('Subject %2d/%2d\n', idata, max(cfg.subjects))
    rng(idata*100,'twister');
    participant = unique(data.name(data.subject == idata));
    hdr = load(fullfile(cfg.meg_dir,sprintf('%s_header.mat',participant{1})),'fsample','tim');
    fsample = hdr.fsample;
    tim = hdr.tim/fsample;
    isubj = data.subject == idata;

    % trials of the condition split into halves
    rows = find(isubj & data.('tap/lis') == cfg.cond);
    data_meg = prepare_meg_data(cfg, participant{1}, condname{cfg.cond}, fsample);
    if size(data_meg,1) ~= numel(rows)
        error('%s%s: %d trials in MEG data but %d in data table!', participant{1}, condname{cfg.cond}, size(data_meg,1), numel(rows));
    end
    itrl  = data.position(rows) >= cfg.nstart & data.('tar/dis')(rows) == cfg.sound; % tones from position nstart
    x_all = data.(cfg.reg)(rows(itrl));
    if any(isnan(x_all))
        error('%s has %d NaN values for subject %d: check cfg.nstart!', cfg.reg, sum(isnan(x_all)), idata);
    end
    y_all = data_meg(itrl,:,:);
    clear data_meg
    ntrl  = size(x_all, 1);
    nsen  = size(y_all, 2);
    nsmp  = size(y_all, 3);

    % noise model from the other condition
    rows_n = find(isubj & data.('tap/lis') == cond_noise);
    data_meg = prepare_meg_data(cfg, participant{1}, condname{cond_noise}, fsample);
    if size(data_meg,1) ~= numel(rows_n)
        error('%s%s: %d trials in MEG data but %d in data table!', participant{1}, condname{cond_noise}, size(data_meg,1), numel(rows_n));
    end
    % white noise: baseline of the same soundtype
    itn = data.position(rows_n) >= cfg.nstart & data.('tar/dis')(rows_n) == cfg.sound; % tones from position nstart
    y_baseline  = data_meg(itn,:,tim < 0);
    baseline_2d = reshape(permute(y_baseline, [1 3 2]), size(y_baseline,1)*size(y_baseline,3), size(y_baseline,2));
    mu_noise    = mean(baseline_2d, 1);
    cov_noise   = cov(baseline_2d);
    clear y_baseline baseline_2d
    clear data_meg

    % shuffle trials with fixed seed and split them into two halves
    rng(12345,'twister');
    idx_shuf = randperm(ntrl);
    x_all    = x_all(idx_shuf);
    y_all    = y_all(idx_shuf,:,:);

    half1_idx = 1:floor(ntrl/2);
    half2_idx = floor(ntrl/2)+1:ntrl;
    x_h1 = x_all(half1_idx);
    y_h1 = y_all(half1_idx,:,:);
    x_h2 = x_all(half2_idx);
    y_h2 = y_all(half2_idx,:,:);
    clear y_all

    % fold indices for each half independently, for each split: split 1 takes
    % the trials of the (shuffled) halves in order,
    % split k > 1 shuffles the trials of each half with seed idata*100+k-1
    ntrl1 = numel(half1_idx);
    ntrl2 = numel(half2_idx);
    fold_idx_h1 = cell(cfg.nsplit,1);
    fold_idx_h2 = cell(cfg.nsplit,1);
    for isplit = 1:cfg.nsplit
        if isplit == 1
            perm1 = 1:ntrl1;
            perm2 = 1:ntrl2;
        else
            rng(idata*100 + isplit - 1,'twister');
            perm1 = randperm(ntrl1);
            perm2 = randperm(ntrl2);
        end
        fold_idx_h1{isplit} = make_folds(perm1, nfold);
        fold_idx_h2{isplit} = make_folds(perm2, nfold);
    end

    % noise
    if cfg.noise_level > 0
        rng(99999 + idata,'twister'); % fixed but subject-specific seed for reproducibility
        noise_h1 = mvnrnd(mu_noise, cov_noise, ntrl1 * nsmp);
        noise_h1 = permute(reshape(noise_h1, ntrl1, nsmp, nsen), [1 3 2]);
        noise_h2 = mvnrnd(mu_noise, cov_noise, ntrl2 * nsmp);
        noise_h2 = permute(reshape(noise_h2, ntrl2, nsmp, nsen), [1 3 2]);
        y_h1_noisy = y_h1 + cfg.noise_level * noise_h1;
        y_h2_noisy = y_h2 + cfg.noise_level * noise_h2;
        clear noise_h1 noise_h2
    else
        y_h1_noisy = y_h1;
        y_h2_noisy = y_h2;
    end

    % decodings: {name, x train, y train, x test, y test, folds train, folds test}
    % (folds: one set per split)
    dec = {
        'within_h1',                  x_h1, y_h1,       x_h1, y_h1,       fold_idx_h1, fold_idx_h1
        'within_h2',                  x_h2, y_h2,       x_h2, y_h2,       fold_idx_h2, fold_idx_h2
        'within_h1_noisy',            x_h1, y_h1_noisy, x_h1, y_h1_noisy, fold_idx_h1, fold_idx_h1
        'within_h2_noisy',            x_h2, y_h2_noisy, x_h2, y_h2_noisy, fold_idx_h2, fold_idx_h2
        'transfer_h1_h2',             x_h1, y_h1,       x_h2, y_h2,       fold_idx_h1, fold_idx_h2
        'transfer_h2_h1',             x_h2, y_h2,       x_h1, y_h1,       fold_idx_h2, fold_idx_h1
        'transfer_h1_h2_noisy',       x_h1, y_h1,       x_h2, y_h2_noisy, fold_idx_h1, fold_idx_h2
        'transfer_h1_noisy_h2',       x_h1, y_h1_noisy, x_h2, y_h2,       fold_idx_h1, fold_idx_h2
        'transfer_h2_h1_noisy',       x_h2, y_h2,       x_h1, y_h1_noisy, fold_idx_h2, fold_idx_h1
        'transfer_h2_noisy_h1',       x_h2, y_h2_noisy, x_h1, y_h1,       fold_idx_h2, fold_idx_h1
        };
    out_dec_ctrl = [];
    out_dec_ctrl.noise_level = cfg.noise_level;
    out_dec_ctrl.noise_type  = 'white';
    out_dec_ctrl.tim         = tim;
    for idec = 1:size(dec,1)
        fprintf('\t%2d: %s (%d split(s))...', idec, dec{idec,1}, cfg.nsplit);
        Chat = zeros(numel(dec{idec,4}), nsmp);
        rdec_split = nan(cfg.nsplit, nsmp);
        for isplit = 1:cfg.nsplit
            Chat_split = decode_ridg_transfer(dec{idec,2}, dec{idec,3}, dec{idec,4}, dec{idec,5}, dec{idec,6}{isplit}, dec{idec,7}{isplit}, alpha);
            Chat = Chat + Chat_split;
            rdec_split(isplit,:) = corr(dec{idec,4}, Chat_split);
        end
        Chat = Chat/cfg.nsplit; % decoded value of each trial averaged over the splits
        out_dec_ctrl.(['zdec_' dec{idec,1}]) = r2z(corr(dec{idec,4}, Chat)); % time-resolved decoding precision (Fisher z)
        if cfg.nsplit > 1
            out_dec_ctrl.(['zdec_split_' dec{idec,1}]) = r2z(rdec_split);
        end
        fprintf('done.\n')
    end
    clear dec y_h1 y_h2 y_h1_noisy y_h2_noisy

    % save
    dec_cfg = cfg;
    dec_cfg.idata = idata;
    fname_out = fullfile(zdec_dir, sprintf('transfer_ctrl_splithalf_%s_%dhz_idata%d_ridge_alpha_%d%s%s_noise-white-%.2f%s', ...
        cfg.reg, cfg.flowpass, idata, cfg.alpha, condname{cfg.cond}, upper(soundname{cfg.sound}), cfg.noise_level, excltag));
    save([fname_out '.mat'], 'out_dec_ctrl', 'tim', 'dec_cfg');
    fprintf('\tSaved: %s\n', fname_out);
    fprintf('Elapsed time: %.1f min\n', toc/60);
end
end

function cfg = set_default(cfg,field,value)
if ~isfield(cfg,field)
    cfg.(field) = value;
end
end

function fold = make_folds(perm, nfold)
% nfold folds of the trials 1:numel(perm): fold k tests the trials
% perm(k), perm(k+nfold), ... and trains on all the others
n = numel(perm);
fold.trn = cell(nfold,1);
fold.tst = cell(nfold,1);
for ifold = 1:nfold
    fold.tst{ifold} = sort(perm(mod((1:n)', nfold) == ifold-1));
    fold.tst{ifold} = fold.tst{ifold}(:);
    fold.trn{ifold} = setdiff((1:n)', fold.tst{ifold});
end
end

function npos_excl = default_npos_excl(reg)
% number of first tones of each sequence for which the regressor is not
% defined (comparative regressors), as in decode_from_sensors
switch reg
    case {'pS','evidence_lag1','cons','update','consall','PE','pitch_lag1'}
        npos_excl = 1;
    case {'evidence_lag2','pSa','consdis','constru','construall','freq_t2','pitch_lag2'}
        npos_excl = 2;
    case {'cE_t3','pS_t2','dfq_t3'}
        npos_excl = 3;
    case {'pS_t3','cE_t4','dfq_t4'}
        npos_excl = 4;
    otherwise
        npos_excl = 0;
end
end
