function [excluded, quality] = meg_quality_check(cfg)
% MEG_QUALITY_CHECK  Participants excluded from the MEG analyses because of noisy channels
%
%  Usage: [excluded, quality] = meg_quality_check(cfg)
%         [excluded, quality] = meg_quality_check()   default options
%
%  For each participant and condition, the s.d. of each channel is computed over all
%  trials and time samples of the MEG epochs. The noise of the worst channels of a
%  participant is the prc-th percentile of its channel s.d., divided by their median
%  (worst condition). A participant is excluded when this value is an outlier relative to
%  the group: modified z-score > z_threshold (Iglewicz and Hoaglin, 1993), with
%  modified z = 0.6745 * (x - median(x)) / median(|x - median(x)|) over participants.
%
%  cfg options:
%        meg_dir      folder of the MEG epochs                      [default: config_paths]
%        table        trial table (participant names and numbers)   [default: config_paths]
%        results_dir  folder of the saved channel s.d. (meg_quality.mat), computed once
%                     and reused                                    [default: config_paths]
%        prc          percentile of the channel s.d.                [default: 99]
%        z_threshold  modified z-score above which a participant is excluded [default: 3.5]
%        recompute    compute the channel s.d. again                [default: false]
%
%  excluded is a cell array of the names of the excluded participants (e.g. {'t10','t14'})
%  quality is a table: subject, name, number of channels, noise of the worst channels in
%  each condition, modified z-score, and excluded (true/false)
%
%  Julie Drevet, 2026

% options
if nargin < 1
    cfg = struct();
end
if ~isfield(cfg,'meg_dir') || ~isfield(cfg,'table') || ~isfield(cfg,'results_dir')
    paths = config_paths();
    cfg = set_default(cfg,'meg_dir',paths.meg_dir);
    cfg = set_default(cfg,'table',paths.table);
    cfg = set_default(cfg,'results_dir',paths.results_dir);
end
cfg = set_default(cfg,'prc',99);
cfg = set_default(cfg,'z_threshold',3.5);
cfg = set_default(cfg,'recompute',false);

% participants, in the order of their subject number
load(cfg.table,'data')
nsuj = max(data.subject);
names = cell(nsuj,1);
for isuj = 1:nsuj
    names(isuj) = unique(data.name(data.subject == isuj));
end
condname = {'_tracking','_listen'};

% s.d. of each channel (computed once, then reused)
fname = fullfile(cfg.results_dir,'meg_quality.mat');
if exist(fname,'file') && ~cfg.recompute
    load(fname,'sd_chan','names_sd');
    if ~isequal(names_sd,names)
        error('%s was computed for other participants: use cfg.recompute = true.',fname);
    end
else
    sd_chan = cell(nsuj,2);
    for isuj = 1:nsuj
        for icond = 1:2
            fprintf('channel s.d. of %s%s...\n',names{isuj},condname{icond});
            tmp = load(fullfile(cfg.meg_dir,sprintf('%s%s.mat',names{isuj},condname{icond})),'data');
            x = tmp.data; % trials x channels x time
            clear tmp
            nchan = size(x,2);
            x = reshape(permute(x,[1 3 2]),[],nchan); % (trials x time) x channels
            sd_chan{isuj,icond} = std(double(x),0,1)';
            clear x
        end
    end
    names_sd = names;
    if ~exist(cfg.results_dir,'dir')
        mkdir(cfg.results_dir);
    end
    save(fname,'sd_chan','names_sd');
end

% % noisy channels and excluded participants
nchan = cellfun(@numel,sd_chan(:,1));
worst = cellfun(@(s) prctile(s,cfg.prc)/median(s), sd_chan); % nsuj x 2
score = max(worst,[],2); % worst condition
mad_score = median(abs(score - median(score)));
zmod = 0.6745*(score - median(score))/mad_score;
isexcl = zmod > cfg.z_threshold;
excluded = names(isexcl)';
quality = table((1:nsuj)',names,nchan,worst(:,1),worst(:,2),zmod,isexcl, ...
    'VariableNames',{'subject','name','nchan','worst_tracking','worst_listen','zmod','excluded'});
fprintf('MEG quality: %d participant(s) excluded (modified z-score of the %gth percentile of channel s.d. / median > %g): %s\n', ...
    sum(isexcl),cfg.prc,cfg.z_threshold,strjoin(excluded,', '));
end

function cfg = set_default(cfg,field,value)
if ~isfield(cfg,field)
    cfg.(field) = value;
end
end
