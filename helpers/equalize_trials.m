function [subset] = equalize_trials(data,var, plotornot, var2plot, statornot)
% this function selects only sounds with comparable "metric" (cE or dfq mainly)
% var: 'dfq' (log2(f/fref), bins of 0.1 between -1 and +1) or 'evidence' (|dfq|, bins of 0.1 between 0 and +1)
%   * if data contains all tap/lis tar/dis it equalizes tar+tap tar+lis dis+tap dis+lis
%   * if data contains tar/dis only for tap, it equalizes tar+tap and dis+tap
%   * if data contains tap/lis only for tar, it equalizes tar+tap and tar+lis
% data is a table

if nargin==1
    var = 'dfq';
    plotornot = false;
    var2plot = var;
    statornot = false;
elseif nargin == 2
    plotornot = false;
    var2plot = var;
    statornot = false;
elseif nargin == 3
    var2plot = var;
    statornot = false;
elseif nargin == 4
    statornot = false;
end

if plotornot
    statornot = true;
end


bin_size = 0.1;

% Binning
switch var
    % case 'cE'
    case 'evidence'
        f_start = 0; f_end = +1; 
    % case {'dfq','constru'}
    case 'dfq'
        f_start = -1; f_end = +1;
end
bins = f_start:bin_size:f_end; % bin edges
nbins = numel(bins)-1;

ncond  = numel(unique(data.("tap/lis")));
nsound = numel(unique(data.("tar/dis"))); 

conditions = unique(data.("tap/lis"));
sounds = unique(data.("tar/dis")); 

condname = {'tracking','listen'};
soundname = {'target','distractor'};

f_com = zeros(nbins,ncond,nsound);

f_bin = cell(ncond,nsound);
for icond = 1:ncond
    jcond = conditions(icond);
    for isound = 1:nsound
        jsound = sounds(isound);
        ifilt = data.("tap/lis")==jcond & data.("tar/dis")==jsound;
        fq = data.(var)(ifilt);
        f_bin{icond,isound} = discretize(fq,bins);
        f_com(:,icond,isound) = histcounts(fq,bins)';
    end
end

f_com = min(f_com,[],[2 3]);

% select subset of sounds to equalize frequencies between target and
% distractors from both tapping and listen
subset = false(size(data,1),1);
for icond = 1:ncond
    jcond = conditions(icond);
    for isound = 1:nsound % targets•distractors
        jsound = sounds(isound);
        ifilt = data.("tap/lis")==jcond & data.("tar/dis")==jsound;
        subtmp = false(size(subset(ifilt)));
        for ibin = 1:nbins
            idx = find(f_bin{icond,isound} == ibin);
            if ~(f_com(ibin) == 1 && numel(idx)==1)
                idx = randsample(idx, f_com(ibin)); % randomly select frequencies among available ones
            end
            subtmp(idx) = true;
        end
        subset(ifilt) = subtmp;
    end
end

if statornot
    data_eq = data(subset,:);
    var_eq = cell(2,2);
    nam_eq = [];
    if plotornot,figure('Color','white');end
    for icond = 1:ncond
        jcond = conditions(icond);
        for isound = 1:nsound
            jsound = sounds(isound);
            ifilt = data_eq.("tap/lis")==jcond & data_eq.("tar/dis")==jsound;
            if any(ifilt)
                var_eq{icond,isound} = data_eq.(var2plot)(ifilt);
                if plotornot
                    hold on
                    histogram(data_eq.(var2plot)(ifilt))
                    nam_eq = [nam_eq {[condname{jcond} ' + ' soundname{jsound}]}];
                end
            end
        end
    end
    % paired-ttest when possible
    fprintf('Paired-ttest:\n')
    if ncond == 2 && nsound == 1
        jsound = sounds(1);
        bf_var_eq = bf.ttest(var_eq{1,jsound},var_eq{2,jsound});
        fprintf('Sound: %s • tap versus lis:\tbf = %4.4f \tvar:%s\n',soundname{jsound},bf_var_eq,var2plot)
        title_str = sprintf('BF = %4.5f',bf_var_eq);
    elseif ncond == 1 && nsound == 2
        jcond = conditions(1);
        bf_var_eq = bf.ttest(var_eq{jcond,1},var_eq{jcond,2});
        fprintf('Cond: %s • tar versus dis:\tbf = %4.5f \tvar:%s\n',condname{jcond},bf_var_eq,var2plot)
        title_str = sprintf('BF = %4.5f',bf_var_eq);
    elseif ncond == 2 && nsound == 2
        for icond = 1:2
            jcond = conditions(icond);
            bf_var_eq = bf.ttest(var_eq{jcond,1},var_eq{jcond,2});
            fprintf('Cond: %s • tar versus dis:\tbf = %4.5f \tvar:%s\n',condname{jcond},bf_var_eq,var2plot)
        end
        for isound = 1:2
            jsound = sounds(1);
            bf_var_eq = bf.ttest(var_eq{1,jsound},var_eq{2,jsound});
            fprintf('Sound: %s • tap versus lis:\tbf = %4.5f \tvar:%s\n',soundname{jsound},bf_var_eq,var2plot)
        end
    end  

    if plotornot
        legend(nam_eq)
        xlabel(var2plot)
        if ~any(cellfun(@isempty,var_eq(:)))
            [tbl, ~] = simple_mixed_anova(cell2mat(var_eq(:)'));
            title(sprintf('BF = %4.5f',bf.bfFromF(tbl.F(3),tbl.DF(3),tbl.DF(4),size(cell2mat(var_eq(:)'),1))));
        else
            try
                title(title_str)
            end
        end
    end
    
end
    %
end