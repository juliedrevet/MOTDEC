%% decode_transfer_from_sensors
% Transfer decoding of a regressor from MEG sensors, together with the within
% decoding computed with the SAME folds:
%   cfg.across = 'condition': between tracking and listen, for a soundtype,
%                no equalization
%   cfg.across = 'soundtype': between targets and distractors, within a condition; targets and
%                distractors are equalized on dfq as in decode_from_sensors with
%                cfg.equalize = 'soundtype' (same seed and trials)
%
% The trials of each group (condition or soundtype) are shuffled (fixed seed)
% and split into nfold folds, identical at every time point. For each test group
% and each fold k, the decoder is trained on the other folds of the train group
% (the test group itself = within, the other group = transfer) and tested on fold
% k of the test group. Within and transfer are thus tested on the same trials,
% with training sets of the same size. With cfg.nsplit > 1, this is repeated for
% nsplit random splits into folds and the decoded values are averaged over the
% splits, as in decode_from_sensors.
%
% Saved for each pair of train and test groups (4 files per participant and
% soundtype or condition), light results as in decode_from_sensors:
%   out_dec.Ctru  true regressor values of the test trials     (ntrl x 1)
%   out_dec.Chat  decoded values of the test trials            (ntrl x ntime)
%   out_dec.rdec  decoding precision (Pearson r)               (1 x ntime)
%   out_dec.rdec_split  decoding precision of each split       (nsplit x ntime, only if nsplit > 1)
%   subidx        rows of the data table (cfg.table) of the test trials, in the
%                 same order as Ctru/Chat: data.(reg)(subidx) == out_dec.Ctru
%   tim           time vector (s)
%   dec_cfg       options used, with igrp_trn and igrp_tst (conditions or soundtypes)
%
% cfg fields (only cfg.reg is required):
%   reg           regressor to decode, column of the data table (e.g. 'pitch')
%   across        'condition' [default] or 'soundtype'
%   sound         soundtype(s) for across = 'condition': 1 = target, 2 = distractor [default: 1]
%   cond          condition(s) for across = 'soundtype': 1 = tracking, 2 = listen   [default: [1 2]]
%   alpha         ridge regularization parameter                   [default: 500]
%   hilbert       true: real + imaginary parts of the Hilbert transform,
%                 false: signals (see decode_from_sensors)         [default: true]
%   flowpass      low-pass frequency (Hz), or [] for raw signals
%                 (only without Hilbert transform)                 [default: 8]
%   nfold         number of cross-validation folds                 [default: 5]
%   nsplit        number of random splits of the trials into folds [default: 1]
%                 split 1 shuffles the trials with the seed idata*100,
%                 split k > 1 with rng(idata*100+k-1,'twister'); the trials
%                 (and their equalization) are the same for all splits; with
%                 nsplit > 1, Chat is the decoded value of each trial averaged over
%                 the splits and rdec = corr(Ctru, Chat)
%   nstart        position in the sequence of the first tone to decode, e.g. 2 = from the
%                 second tone (1 = all tones)                    [default: set from reg]
%   subjects      subjects to decode     [default: all, except those excluded by meg_quality_check]
%   meg_dir       folder of the MEG epochs and header files        [default: config_paths]
%   prep_dir      folder of the prepared MEG data                  [default: config_paths]
%   save_prepared save the prepared MEG data (prepare_meg_data)   [default: true]
%   table         trial table (full path)                          [default: config_paths]
%   out_dir       results are saved in <out_dir>/<reg>/            [default: config_paths]
%
% Output files (<signal>, _start<n> and _nsplit<n> as in decode_from_sensors):
%   across = 'condition': <out_dir>/<reg>/transfer_out_dec_<reg>_<signal>_idata<n>_ridge_alpha_<alpha>_TRN_<cond>_TST_<cond>_<SOUND>_eq-none.mat
%     e.g. transfer_out_dec_evidence_8hz_idata1_ridge_alpha_500_TRN_listen_TST_tracking_TAR_eq-none.mat   (transfer)
%          transfer_out_dec_evidence_8hz_idata1_ridge_alpha_500_TRN_tracking_TST_tracking_TAR_eq-none.mat (within)
%   across = 'soundtype': <out_dir>/<reg>/transfer_out_dec_<reg>_<signal>_idata<n>_ridge_alpha_<alpha>_TRN_<sound>_TST_<sound>_<COND>_eq-soundtype.mat
%     e.g. transfer_out_dec_pitch_8hz_idata1_ridge_alpha_500_TRN_tar_TST_dis_LISTEN_eq-soundtype.mat      (transfer)
%          transfer_out_dec_pitch_8hz_idata1_ridge_alpha_500_TRN_dis_TST_dis_LISTEN_eq-soundtype.mat      (within)
%
% Examples
%   cfg = []; cfg.reg = 'evidence'; cfg.sound = 1;
%   decode_transfer_from_sensors(cfg)       % tracking <-> listen, targets
%   cfg = []; cfg.reg = 'pitch'; cfg.across = 'soundtype';
%   decode_transfer_from_sensors(cfg)       % targets <-> distractors, in tracking and in listen
function decode_transfer_from_sensors(cfg)

% options
if ~isfield(cfg,'reg')
    error('cfg.reg is required!');
end
cfg = set_default(cfg,'across','condition');
cfg = set_default(cfg,'sound',1);
cfg = set_default(cfg,'cond',[1 2]);
cfg = set_default(cfg,'alpha',500);
cfg = set_default(cfg,'hilbert',true);
cfg = set_default(cfg,'flowpass',8);
if cfg.hilbert && isempty(cfg.flowpass)
    error('the Hilbert data are low-pass filtered: cfg.flowpass cannot be empty!');
end
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
if ~ismember(cfg.across,{'condition','soundtype'})
    error('unknown cfg.across ''%s'': use ''condition'' or ''soundtype''!',cfg.across);
end
cfg.sound = cfg.sound(:)';   % row vectors for the for loops
cfg.cond = cfg.cond(:)';

% file name tags
if cfg.hilbert
    sigtag = sprintf('%dhz',cfg.flowpass);
elseif isempty(cfg.flowpass)
    sigtag = 'nohilbert_raw';
else
    sigtag = sprintf('nohilbert_%dhz',cfg.flowpass);
end
if cfg.nstart == nstart_reg
    excltag = '';
else
    excltag = sprintf('_start%d',cfg.nstart);
end
if cfg.nsplit > 1
    excltag = [excltag sprintf('_nsplit%d',cfg.nsplit)];
end

condname = {'_tracking', '_listen'};
soundname = {'_tar', '_dis'};

fprintf('Transfer decoding %s across %ss (%s)\n', cfg.reg, cfg.across, sigtag);

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

%% DECODING
tic
for idata = cfg.subjects
    fprintf('Subject %2d/%2d\n',idata,max(cfg.subjects))
    participant = unique(data.name(data.subject == idata));
    hdr = load(fullfile(cfg.meg_dir,sprintf('%s_header.mat',participant{1})),'fsample','tim');
    tim = hdr.tim/hdr.fsample;
    isubj = data.subject == idata;

    % MEG data of the conditions needed, with the rows of the data table of each
    % condition, in the same order as the trials of the MEG files
    if strcmp(cfg.across,'condition')
        conds = [1 2];
    else
        conds = cfg.cond;
    end
    meg = cell(1,2); condrows = cell(1,2);
    for icond = conds
        condrows{icond} = find(isubj & data.('tap/lis') == icond);
        fprintf('\tloading cond%2d/2...',icond);
        meg{icond} = prepare_meg_data(cfg, participant{1}, condname{icond}, hdr.fsample);
        fprintf('done.\n')
        if size(meg{icond},1) ~= numel(condrows{icond})
            error('%s%s: %d trials in MEG data but %d in data table!', ...
                participant{1}, condname{icond}, size(meg{icond},1), numel(condrows{icond}));
        end
    end

    % groups between which the decoders are transferred
    if strcmp(cfg.across,'condition')
        nset = numel(cfg.sound);
    else
        nset = numel(cfg.cond);
    end
    for iset = 1:nset
        x = cell(1,2); y = cell(1,2); subidx_grp = cell(1,2); fold = cell(cfg.nsplit,2);
        if strcmp(cfg.across,'condition')
            % groups = conditions, for one soundtype, no equalization
            isound = cfg.sound(iset);
            rng(idata*100,'twister'); % fixed seed: shuffling of the trials before the folds
            for igrp = 1:2
                rows = condrows{igrp};
                % trials of the soundtype, without the first tone(s) of each sequence
                % if the regressor is comparative
                itrl = data.position(rows) >= cfg.nstart & data.('tar/dis')(rows) == isound; % tones from position nstart
                subidx_grp{igrp} = rows(itrl);
                y{igrp} = meg{igrp}(itrl,:,:);
            end
            grpname = condname;
            settag = upper(soundname{isound});
            eqtag = '_eq-none';
        else
            % groups = soundtypes, for one condition, equalized on dfq as in
            % decode_from_sensors with cfg.equalize = 'soundtype'
            icond = cfg.cond(iset);
            rows = condrows{icond};
            ipool = find(data.position(rows) >= cfg.nstart); % tones from position nstart
            rng(idata*100,'twister'); % same seed and trials as decode_from_sensors
            subset = equalize_trials(data(rows(ipool),:), 'dfq');
            ikeep = false(size(rows));
            ikeep(ipool(subset)) = true;
            for igrp = 1:2
                itrl = ikeep & data.('tar/dis')(rows) == igrp;
                subidx_grp{igrp} = rows(itrl);
                y{igrp} = meg{icond}(itrl,:,:);
            end
            grpname = soundname;
            settag = upper(condname{icond});
            eqtag = '_eq-soundtype';
        end
        for igrp = 1:2
            x{igrp} = data.(cfg.reg)(subidx_grp{igrp});
            if any(isnan(x{igrp}))
                error('%s has %d NaN values for subject %d%s%s: check cfg.nstart!', ...
                    cfg.reg, sum(isnan(x{igrp})), idata, grpname{igrp}, lower(settag));
            end
        end
        % folds: trials shuffled, same folds at every time point and for within
        % and transfer decoding; split 1 continues the stream seeded above with
        % idata*100, split k > 1 is seeded with idata*100+k-1
        for isplit = 1:cfg.nsplit
            if isplit > 1
                rng(idata*100 + isplit - 1,'twister');
            end
            for igrp = 1:2
                ntrl = numel(x{igrp});
                idx_shuf = randperm(ntrl);
                fold{isplit,igrp}.tst = cell(cfg.nfold,1);
                fold{isplit,igrp}.trn = cell(cfg.nfold,1);
                for ifold = 1:cfg.nfold
                    fold{isplit,igrp}.tst{ifold} = sort(idx_shuf(mod((1:ntrl)', cfg.nfold) == ifold-1))';
                    fold{isplit,igrp}.trn{ifold} = setdiff((1:ntrl)', fold{isplit,igrp}.tst{ifold});
                end
            end
        end

        for igrp_tst = 1:2
            for igrp_trn = 1:2
                if igrp_trn == igrp_tst
                    fprintf('\t%s: within %s (%d split(s))...', lower(settag), grpname{igrp_tst}(2:end), cfg.nsplit);
                else
                    fprintf('\t%s: transfer %s -> %s (%d split(s))...', lower(settag), grpname{igrp_trn}(2:end), grpname{igrp_tst}(2:end), cfg.nsplit);
                end
                Chat = zeros(numel(x{igrp_tst}),size(y{igrp_tst},3));
                rdec_split = nan(cfg.nsplit,size(y{igrp_tst},3));
                for isplit = 1:cfg.nsplit
                    Chat_split = decode_ridg_transfer(x{igrp_trn}, y{igrp_trn}, x{igrp_tst}, y{igrp_tst}, ...
                        fold{isplit,igrp_trn}, fold{isplit,igrp_tst}, cfg.alpha);
                    Chat = Chat + Chat_split;
                    rdec_split(isplit,:) = corr(x{igrp_tst}, Chat_split);
                end
                fprintf('done.\n')

                out_dec = [];
                out_dec.Ctru = x{igrp_tst};
                out_dec.Chat = Chat/cfg.nsplit; % decoded value of each trial averaged over the splits
                out_dec.rdec = corr(out_dec.Ctru, out_dec.Chat);
                if cfg.nsplit > 1
                    out_dec.rdec_split = rdec_split;
                end
                subidx = subidx_grp{igrp_tst};

                dec_cfg = cfg;
                dec_cfg.idata = idata;
                dec_cfg.igrp_trn = igrp_trn;
                dec_cfg.igrp_tst = igrp_tst;
                if strcmp(cfg.across,'condition')
                    dec_cfg.sound = isound;
                else
                    dec_cfg.cond = icond;
                end

                fname_out = fullfile(zdec_dir,sprintf('transfer_out_dec_%s_%s_idata%d_ridge_alpha_%d_TRN%s_TST%s%s%s%s', ...
                    cfg.reg,sigtag,idata,cfg.alpha,grpname{igrp_trn},grpname{igrp_tst},settag,eqtag,excltag));
                save([fname_out '.mat'], 'out_dec','subidx','tim','dec_cfg');
            end
        end
    end
    clear meg x y
    fprintf('elapsed time since beginning: %.1f min\n', toc/60);
end
end

function cfg = set_default(cfg,field,value)
if ~isfield(cfg,field)
    cfg.(field) = value;
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
