%% make_table_from_header
% builds the trial table (one row per tone) from the header files of
% the MEG data (<participant>_header.mat): raw trial information, plus the
% variables used in the paper:
%   subject, name        participant number and name
%   jitter               tone onset minus its expected onset on the 3-Hz beat grid (timing precision)
%   iscor                correct choice w.r.t. the mean of the log2 frequencies of the 8 targets
%   pitch                log2(f)
%   dfq                  log2(f/fref), fref = 440 Hz
%   evidence             evidence strength |log2(f/fref)|
%   update               belief update: evidence of the current target signed by
%                        the evidence accumulated over the previous targets (targets only)
%   pitch_lag2, evidence_lag2   value of the previous tone of the same type (carry-over)

clearvars
close all
clc

paths = config_paths();
origDir = paths.meg_dir;
condname = {'_tracking', '_listen'};

HEADER = dir(fullfile(origDir,'*header.mat'));
[~,isort] = sort({HEADER.name});
HEADER = HEADER(isort);
nsuj = length(HEADER);

data = [];
for isuj = 1:nsuj
    fprintf('Subject %2d/%2d...\n',isuj,nsuj);
    hdr = load(fullfile(HEADER(isuj).folder,HEADER(isuj).name), 'header');
    subname = HEADER(isuj).name(1:3);
    in = load(fullfile(HEADER(isuj).folder,HEADER(isuj).name), 'index');
    tsubj = array2table(in.index,'VariableNames',hdr.header);
    subtable = array2table(repmat({subname},size(tsubj,1),1),'VariableNames',{'name'});
    sidtable = array2table(repmat(isuj,size(tsubj,1),1),'VariableNames',{'subject'});
    onbeat = repmat((3+(0:15)/3)',size(tsubj,1)/16,1);
    jitter = tsubj.onset-onbeat;
    jittable = array2table(jitter,'VariableNames',{'jitter'});
    tsubj = [sidtable,subtable,tsubj,jittable];
    data = cat(1,data,tsubj);
end
iscor = false(size(data,1),1);
data = [data,table(iscor)];

%% add regressors to table
f_ref = 440;
ntone = 16;
pitch = log2(data.freq);
dfq = log2(data.freq/f_ref);
evidence = abs(dfq);
data = [data,table(pitch,dfq,evidence)];

%% add correct answer or not
for idata = 1:nsuj
    ifilt = data.subject == idata & data.("tar/dis") == 1;
    x = reshape(data.dfq(ifilt),ntone/2,[]);
    r = reshape(data.response(ifilt),ntone/2,[]);
    iscor_tmp = sign(mean(x))==sign(mean(r));
    ifilt = data.subject == idata;
    data.iscor(ifilt) = repelem(iscor_tmp(:),ntone);
end

%% add update => evidence of each target signed by the evidence accumulated over the previous targets
% (not defined for the first target, nor for distractors)
data.update = nan(size(data,1),1);
for idata = 1:nsuj
    ifilt = data.subject == idata & data.("tar/dis") == 1;
    x = reshape(data.dfq(ifilt),ntone/2,[]);
    y = [nan(1,size(x,2));cumsum(x(1:end-1,:))];
    update_tmp = sign(y).*x;
    data.update(ifilt) = update_tmp(:);
end

%% lagged pitch and evidence: value of the tone 1 or 2 positions before in the
% same sequence (lag2 = previous tone of the same type), NaN when there is none
% for lag = 1:2
for lag = 2
    tmp = [nan(lag,1); data.pitch(1:end-lag)];
    tmp(data.position <= lag) = nan;
    data.(sprintf('pitch_lag%d',lag)) = tmp;
    tmp = [nan(lag,1); data.evidence(1:end-lag)];
    tmp(data.position <= lag) = nan;
    data.(sprintf('evidence_lag%d',lag)) = tmp;
end

save(paths.table,'data')
