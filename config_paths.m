function paths = config_paths()
% CONFIG_PATHS  Folders and toolboxes used by the MOTDEC scripts
%
%  Usage: paths = config_paths()
%
%  Default folders, all inside the MOTDEC folder (the large ones are not on GitHub,
%  see .gitignore):
%    paths.root             MOTDEC folder (code)
%    paths.table            trial table                                 data/motdat_data.mat
%    paths.meg_dir          MEG epochs and header files (from Zenodo)   data/meg/
%    paths.prep_dir         prepared MEG data (prepare_meg_data)        prepared_data/
%    paths.results_dir      decoding results                            results/
%    paths.fig_dir          figures                                     figs/
%    paths.fieldtrip_dir    FieldTrip folder, if not already on the MATLAB path
%    paths.bayesfactor_dir  Bayes Factor Toolbox folder (Krekelberg, 2024), if not
%                           already on the MATLAB path
%
%  To use other folders on your computer (e.g. MEG data stored elsewhere), create the
%  file config_paths_local.m in the MOTDEC folder:
%         function local = config_paths_local()
%         local = [];
%         local.meg_dir         = '/path/to/meg/data/';
%         local.fieldtrip_dir   = '/path/to/fieldtrip/';
%         local.bayesfactor_dir = '/path/to/bayesFactor/';
%         end
%  config_paths then uses these folders instead of the default ones.
%
%  Julie Drevet with claude, 2026

% default folders
root = fileparts(mfilename('fullpath'));
paths = [];
paths.root            = root;
paths.table           = fullfile(root,'data','motdat_data.mat');
paths.meg_dir         = fullfile(root,'data','meg');
paths.prep_dir        = fullfile(root,'prepared_data');
paths.results_dir     = fullfile(root,'results');
paths.fig_dir         = fullfile(root,'figs');
paths.fieldtrip_dir   = '';
paths.bayesfactor_dir = '';

% local settings
if exist(fullfile(root,'config_paths_local.m'),'file')
    local = config_paths_local();
    fields = fieldnames(local);
    for i = 1:numel(fields)
        paths.(fields{i}) = local.(fields{i});
    end
end

% MATLAB path
addpath(root);
addpath(fullfile(root,'helpers'));
if ~isempty(paths.fieldtrip_dir) && ~exist('ft_defaults','file')
    addpath(paths.fieldtrip_dir);
end
if exist('ft_defaults','file') && ~exist('ft_preproc_lowpassfilter','file')
    ft_defaults
end
if ~isempty(paths.bayesfactor_dir)
    addpath(paths.bayesfactor_dir);
end

% output folders
outdirs = {paths.prep_dir, paths.results_dir, paths.fig_dir};
for i = 1:numel(outdirs)
    if ~exist(outdirs{i},'dir')
        mkdir(outdirs{i});
    end
end
end
