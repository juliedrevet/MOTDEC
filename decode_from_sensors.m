%% decode_from_sensors
% DECODE_FROM_SENSORS  Time-resolved ridge decoding of a variable from MEG signals, separately
% for each condition (tracking, listen) and each sound type (target, distractor)
%
% Usage: decode_from_sensors(cfg)
%
% At each time sample of the tone-locked epochs, the variable cfg.reg of each tone is decoded
% from the MEG features (real and imaginary parts of the Hilbert transform of each channel,
% or the low-pass filtered signals) with ridge regression (decode_ridg): nfold-fold
% cross-validation, repeated nsplit times with different random partitions of the trials;
% the decoded value of each trial is averaged over the repetitions before computing the
% decoding precision (Pearson correlation with the true values).
%
% cfg fields (only cfg.reg is required):
%   reg           variable to decode, column of the trial table, e.g. 'pitch', 'evidence',
%                 'update' (targets only), 'pitch_lag2', 'evidence_lag2' (carry-over)
%   cond          conditions to decode: 1 = tracking, 2 = listen             [default: [1 2]]
%   sound         sound types to decode: 1 = target, 2 = distractor         [default: [1 2]]
%   equalize      equalize the pitch distributions (dfq, equalize_trials) before decoding:
%                   'none'       no equalization                            [default]
%                   'soundtype'  targets vs distractors, within each condition
%                   'condition'  tracking vs listen, within each sound type
%                   'all'        the four condition x sound type cells together
%   alpha         ridge regularization parameter                             [default: 500]
%   hilbert       true: real and imaginary parts of the Hilbert transform,
%                 false: signals                                             [default: true]
%   flowpass      low-pass frequency (Hz), or [] for raw signals (only without Hilbert) [default: 8]
%   save_prepared save the prepared MEG data (prepare_meg_data)              [default: true]
%   nfold         number of cross-validation folds                           [default: 5]
%   nsplit        number of random partitions of the trials into folds (the paper uses 10);
%                 partition k shuffles the trials with rng(12345+k-1,'twister')   [default: 1]
%   nstart        position in the sequence of the first tone to decode, e.g. 2 = from the
%                 second tone (1 = all tones)                    [default: set from reg]
%   subjects      subjects to decode   [default: all, except those excluded by meg_quality_check]
%   meg_dir       folder of the MEG epochs and header files                  [default: config_paths]
%   prep_dir      folder of the prepared MEG data                            [default: config_paths]
%   table         trial table (full path)                                    [default: config_paths]
%   out_dir       results are saved in <out_dir>/<reg>/                      [default: config_paths]
%
% MEG data, prepared by prepare_meg_data from the epochs <participant><cond>.mat:
%   hilbert = true               low-pass filter + real and imaginary parts of the Hilbert transform
%   hilbert = false, flowpass    low-pass filter only
%   hilbert = false, flowpass [] raw signals, not filtered
%
% Equalization only uses the trial table and always uses all the trials of the subject
% (from position nstart), whatever cfg.cond and cfg.sound: decoding the cells in separate
% calls gives the same trials as decoding them together.
%
% Saved, one file per participant, condition and sound type:
%   out_dec.Ctru        true values                                       (ntrl x 1)
%   out_dec.Chat        cross-validated decoded values, averaged over the partitions (ntrl x ntime)
%   out_dec.rdec        decoding precision (Pearson r)                    (1 x ntime)
%   out_dec.rdec_split  decoding precision of each partition (only if nsplit > 1) (nsplit x ntime)
%   subidx              rows of the trial table of these trials, in the same order as
%                       Ctru/Chat: data.(reg)(subidx) == out_dec.Ctru
%   tim                 time vector (s)
%   dec_cfg             options used (not called cfg, so that load(fname) does not
%                       overwrite the cfg of the analyses scripts)
% in <out_dir>/<reg>/out_dec_<reg>_<signal>_idata<n>_ridge_alpha_<alpha>_<cond>_<SOUND>_eq-<equalize>.mat
%   with <signal> = <flowpass>hz (Hilbert), nohilbert_<flowpass>hz or nohilbert_raw,
%   _start<n> added when cfg.nstart differs from the default of reg, and _nsplit<n> when
%   cfg.nsplit > 1, e.g. out_dec_pitch_8hz_idata1_ridge_alpha_500_tracking_TAR_eq-none_nsplit10.mat
%
% Examples (analyses of the paper)
%   % pitch (or evidence strength) of targets and distractors, in each condition (Fig. 2, 3)
%   cfg = []; cfg.reg = 'pitch'; cfg.nsplit = 10;
%   decode_from_sensors(cfg)
%
%   % targets vs distractors, with equalized pitch distributions (Fig. 2, Supp. Fig. 3)
%   cfg = []; cfg.reg = 'pitch'; cfg.equalize = 'soundtype'; cfg.nsplit = 10;
%   decode_from_sensors(cfg)
%
%   % belief update, targets only (Fig. 2, 3)
%   cfg = []; cfg.reg = 'update'; cfg.sound = 1; cfg.nsplit = 10;
%   decode_from_sensors(cfg)
%
%   % carry-over: pitch of the previous tone of the same type (Fig. 4d, Supp. Fig. 6b)
%   cfg = []; cfg.reg = 'pitch_lag2'; cfg.nsplit = 10;
%   decode_from_sensors(cfg)
%
%   % without Hilbert transform, low-pass filtered at 8 Hz
%   cfg = []; cfg.reg = 'pitch'; cfg.hilbert = false;
%   decode_from_sensors(cfg)
%
% Julie Drevet, 2026
function decode_from_sensors(cfg)

% options
if ~isfield(cfg,'reg')
    error('cfg.reg is required!');
end
cfg = set_default(cfg,'cond',[1 2]);
cfg = set_default(cfg,'sound',[1 2]);
cfg = set_default(cfg,'equalize','none');
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
cfg.cond = cfg.cond(:)';   % row vectors for the for loops
cfg.sound = cfg.sound(:)';
if ~ismember(cfg.equalize,{'none','soundtype','condition','all'})
    error('unknown cfg.equalize ''%s'': use ''none'', ''soundtype'', ''condition'' or ''all''!',cfg.equalize);
end

% file name tags
if cfg.hilbert
    sigtag = sprintf('%dhz',cfg.flowpass);
elseif isempty(cfg.flowpass)
    sigtag = 'nohilbert_raw';
else
    sigtag = sprintf('nohilbert_%dhz',cfg.flowpass);
end
eqtag = ['_eq-' cfg.equalize];
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

fprintf('Decoding %s (%s, equalize: %s)\n', cfg.reg, sigtag, cfg.equalize);

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

    % trials of this subject, without the first tone(s) of each sequence
    % if the regressor is comparative
    isubj = data.subject == idata;
    ipool = isubj & data.position >= cfg.nstart; % tones from position nstart

    % equalize dfq between the cells of each group: each group is equalized
    % with the same seed, so that its selection does not depend on the others
    switch cfg.equalize
        case 'none'
            igroup = {};
        case 'soundtype' % target vs distractor, within each condition
            igroup = {ipool & data.('tap/lis') == 1, ipool & data.('tap/lis') == 2};
        case 'condition' % tracking vs listen, within each soundtype
            igroup = {ipool & data.('tar/dis') == 1, ipool & data.('tar/dis') == 2};
        case 'all'
            igroup = {ipool};
    end
    if isempty(igroup)
        ikeep = ipool;
    else
        ikeep = false(size(ipool));
        for igrp = 1:numel(igroup)
            rng(idata*100,'twister');
            rows = find(igroup{igrp});
            subset = equalize_trials(data(rows,:), 'dfq');
            ikeep(rows(subset)) = true;
        end
    end

    for icond = cfg.cond
        % rows of the data table of this condition, in the same order as
        % the trials of the MEG files
        icondrows = find(isubj & data.('tap/lis') == icond);
        fprintf('\tloading cond%2d/2...',icond);
        data_meg = prepare_meg_data(cfg, participant{1}, condname{icond}, hdr.fsample);
        fprintf('done.\n')
        if size(data_meg,1) ~= numel(icondrows)
            error('%s%s: %d trials in MEG data but %d in data table!', ...
                participant{1}, condname{icond}, size(data_meg,1), numel(icondrows));
        end

        for isound = cfg.sound
            itrl = ikeep(icondrows) & data.('tar/dis')(icondrows) == isound; % trials of the MEG data
            subidx = icondrows(itrl);
            xcur = data.(cfg.reg)(subidx);
            if any(isnan(xcur))
                error('%s has %d NaN values for subject %d%s%s: check cfg.nstart!', ...
                    cfg.reg, sum(isnan(xcur)), idata, condname{icond}, soundname{isound});
            end
            ymeg = data_meg(itrl,:,:);
            ntime = size(ymeg,3);
            nfold = cfg.nfold;
            alpha = cfg.alpha;

            fprintf('\tdecoding%s%s (%d trials, %d split(s))...',condname{icond},soundname{isound},numel(xcur),cfg.nsplit)
            Chat = zeros(numel(xcur),ntime);
            rdec_split = nan(cfg.nsplit,ntime);
            for isplit = 1:cfg.nsplit
                seed = 12345 + isplit - 1; % seed of the random partition isplit
                out = cell(1,ntime);
                parfor itime = 1:ntime
                    ycur = ymeg(:,:,itime);
                    out{itime} = decode_ridg(xcur, ycur, nfold, alpha, true, 'pearson', true, seed);
                end
                Chat = Chat + cell2mat(cellfun(@(x) x.Chat,out,'UniformOutput',false));
                rdec_split(isplit,:) = cellfun(@(x) x.rdec,out);
            end
            fprintf('done.\n')

            out_dec = [];
            out_dec.Ctru = xcur;
            out_dec.Chat = Chat/cfg.nsplit; % decoded value of each trial averaged over the splits
            if cfg.nsplit == 1
                out_dec.rdec = rdec_split;
            else
                out_dec.rdec = corr(xcur, out_dec.Chat);
                out_dec.rdec_split = rdec_split;
            end

            dec_cfg = cfg;
            dec_cfg.idata = idata;
            dec_cfg.icond = icond;
            dec_cfg.isound = isound;

            fname_out = fullfile(zdec_dir,sprintf('out_dec_%s_%s_idata%d_ridge_alpha_%d%s%s%s%s', ...
                cfg.reg,sigtag,idata,cfg.alpha,condname{icond},upper(soundname{isound}),eqtag,excltag));
            save([fname_out '.mat'], 'out_dec','subidx','tim','dec_cfg');
        end
        clear data_meg ymeg
    end
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
% defined (comparative regressors)
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
