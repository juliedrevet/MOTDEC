function data_meg = prepare_meg_data(cfg, participant, condname, fsample)
% PREPARE_MEG_DATA  MEG features of one participant and condition, used for decoding
%
%  Usage: data_meg = prepare_meg_data(cfg, participant, condname, fsample)
%
%  where participant is the participant name (e.g. 's01')
%        condname is the condition ('_tracking' or '_listen')
%        fsample is the sampling frequency (Hz) [default: read from <participant>_header.mat]
%
%  and cfg contains the options:
%        meg_dir        folder of the MEG epochs <participant><condname>.mat (variable data,
%                       trials x channels x time) and of the header files    [default: config_paths]
%        hilbert        true: real and imaginary parts of the Hilbert transform,
%                       false: low-pass filtered (or raw) signals            [default: true]
%        flowpass       low-pass frequency (Hz), or [] for no filtering      [default: 8]
%        prep_dir       folder of the prepared files                         [default: config_paths]
%        save_prepared  save the prepared data in prep_dir, so that it is
%                       computed only once                                   [default: true]
%
%  data_meg is trials x features x time (single precision), with features the channels
%  (hilbert = false) or [real parts, imaginary parts] of the channels (hilbert = true).
%
%  Preprocessing of each trial: 2 s of zero-padding on
%  each side, 6th-order Butterworth low-pass filter (FieldTrip ft_preproc_lowpassfilter,
%  two-pass), linear detrend, Hilbert transform (if hilbert = true), padding removed.
%  The raw epochs in meg_dir are only read, never modified.
%
%  Prepared files: <prep_dir>/<participant><condname>_hilbert_<flowpass>Hz.mat (data_real,
%  data_imag) or <prep_dir>/<participant><condname>_lowpass_<flowpass>Hz.mat (data_filt).
%
%  Julie Drevet, 2026

% options
if ~isfield(cfg,'meg_dir') || ~isfield(cfg,'prep_dir')
    paths = config_paths();
    cfg = set_default(cfg,'meg_dir',paths.meg_dir);
    cfg = set_default(cfg,'prep_dir',paths.prep_dir);
end
cfg = set_default(cfg,'hilbert',true);
cfg = set_default(cfg,'flowpass',8);
cfg = set_default(cfg,'save_prepared',true);
if nargin < 4 || isempty(fsample)
    hdr = load(fullfile(cfg.meg_dir,sprintf('%s_header.mat',participant)),'fsample');
    fsample = hdr.fsample;
end

% raw signals: nothing to prepare
if ~cfg.hilbert && isempty(cfg.flowpass)
    tmp = load(fullfile(cfg.meg_dir,sprintf('%s%s.mat',participant,condname)),'data');
    data_meg = tmp.data;
    return
end

% name of the prepared file
if isempty(cfg.flowpass)
    ftag = 'raw';
else
    ftag = sprintf('%gHz',cfg.flowpass);
end
if cfg.hilbert
    fname_prep = fullfile(cfg.prep_dir,sprintf('%s%s_hilbert_%s.mat',participant,condname,ftag));
else
    fname_prep = fullfile(cfg.prep_dir,sprintf('%s%s_lowpass_%s.mat',participant,condname,ftag));
end

% 1. prepared file already there
if exist(fname_prep,'file')
    if cfg.hilbert
        tmp = load(fname_prep,'data_real','data_imag');
        data_meg = cat(2,tmp.data_real,tmp.data_imag);
    else
        tmp = load(fname_prep,'data_filt');
        data_meg = tmp.data_filt;
    end
    return
end

% 2. compute from the raw epochs
if ~exist('ft_preproc_lowpassfilter','file') || ~exist('ft_preproc_hilbert','file')
    error('FieldTrip is not on the MATLAB path (needed to prepare %s).',fname_prep);
end
fprintf('preparing %s%s (hilbert = %d, low-pass = %s)...',participant,condname,cfg.hilbert,ftag);
tmp = load(fullfile(cfg.meg_dir,sprintf('%s%s.mat',participant,condname)),'data');
data = tmp.data;
clear tmp
xcut = 2; % padding (s)
npad = xcut*fsample;
flowpass = cfg.flowpass;
if cfg.hilbert
    % low-pass filter + Hilbert transform
    data_real = nan(size(data),'single');
    data_imag = nan(size(data),'single');
    parfor ievnt = 1:size(data,1)
        x = squeeze(data(ievnt,:,:)); % x : nchan x ntime
        % add padding
        x = cat(2, zeros(size(x,1),npad),x, zeros(size(x,1),npad));
        % low-pass filter
        if ~isempty(flowpass)
            x = ft_preproc_lowpassfilter(x, fsample, flowpass ,6, 'but');
        end
        % remove linear trend
        x = ft_preproc_polyremoval(x,1);
        % hilbert
        x_real = ft_preproc_hilbert(x,'real');
        x_imag = ft_preproc_hilbert(x,'imag');
        data_real(ievnt,:,:) = x_real(:,npad+1:end-npad);
        data_imag(ievnt,:,:) = x_imag(:,npad+1:end-npad);
    end
    data_meg = cat(2,data_real,data_imag);
else
    % low-pass filter only
    data_filt = nan(size(data),'single');
    parfor ievnt = 1:size(data,1)
        x = squeeze(data(ievnt,:,:)); % x : nchan x ntime
        % add padding
        x = cat(2, zeros(size(x,1),npad), x, zeros(size(x,1),npad));
        % low-pass filter
        x = ft_preproc_lowpassfilter(x, fsample, flowpass, 6, 'but');
        % remove linear trend
        x = ft_preproc_polyremoval(x,1);
        data_filt(ievnt,:,:) = x(:,npad+1:end-npad);
    end
    data_meg = data_filt;
end
clear data
fprintf('done.\n')

% save the prepared data
if cfg.save_prepared
    if ~exist(cfg.prep_dir,'dir')
        mkdir(cfg.prep_dir);
    end
    if cfg.hilbert
        save(fname_prep,'data_real','data_imag');
    else
        save(fname_prep,'data_filt');
    end
end
end

function cfg = set_default(cfg,field,value)
if ~isfield(cfg,field)
    cfg.(field) = value;
end
end
