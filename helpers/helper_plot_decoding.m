function stat = helper_plot_decoding(cfg)
% this funciton plots time-resolved decoding
%
% cluster-based permutation tests (sign flips of participants, cluster mass = sum of t):
% the cluster test itself is in cluster_permutation.m
%   cfg.stats0       each decoding curve > 0
%   cfg.statsbetween curve 1 > curve 2 (when 2 curves)
%   cfg.nres         number of permutations [default: 1e5]
%   cfg.alpha        cluster-forming and significance threshold [default: 0.05]
%   cfg.seed         seed of the sign flips, for reproducible results [default: 1]
%   cfg.statmethod   'cluster' [default]: cluster mass (sum of t) of the clusters of
%                    time points with p < alpha (at least 2 samples)
%                    'tfce': threshold-free cluster enhancement of the t-values
%                    (as tfce_1d.m, clusters of at least 2 samples), p-value at each
%                    time point from the maximum TFCE of each permutation (FWER)
%   cfg.tfce_E, cfg.tfce_H, cfg.tfce_dh  TFCE extent and height exponents and
%                    height step [default: 0.5, 2, 0.1]
% output (optional): stat.stats0(idec).clusters and stat.statsbetween.clusters,
%   one row per cluster: [start time, end time, p-value]; p = (#null >= observed + 1)/(nres + 1)
%   with statmethod 'tfce': one row per window of consecutive significant time
%   points, with the smallest p-value of the window; and the p-value of each time
%   point in stat.stats0(idec).tfce_p and stat.statsbetween.tfce_p

stat = struct('stats0',[],'statsbetween',[]);
if isfield(cfg,'seed'), seed = cfg.seed;
else
    seed = 1;
end
if ~isfield(cfg,'statmethod'), cfg.statmethod = 'cluster'; end
if ~ismember(cfg.statmethod,{'cluster','tfce'})
    error('unknown cfg.statmethod ''%s'': use ''cluster'' or ''tfce''!',cfg.statmethod);
end
use_tfce = strcmp(cfg.statmethod,'tfce');
if isfield(cfg,'tfce_E'), tfce_E = cfg.tfce_E; else, tfce_E = 0.5; end
if isfield(cfg,'tfce_H'), tfce_H = cfg.tfce_H; else, tfce_H = 2; end
if isfield(cfg,'tfce_dh'), tfce_dh = cfg.tfce_dh; else, tfce_dh = 0.1; end

if isfield(cfg,'pbar'),pbar = cfg.pbar;
else
    pbar = 1.1;
end
if isfield(cfg,'HGT'),HGT = cfg.HGT;
else
    HGT = 4;
end

if isfield(cfg,'lw'), lw = cfg.lw;
else
    lw = 1; % linewidth
end

% decoding curves to plot
if isfield(cfg,'zdec') % ndata x nsmp x ndec
    zdec = cfg.zdec;
    ndata = size(zdec,1);
    nsmp = size(zdec,2);
    ndec = size(zdec,3);
end
if ~isfield(cfg,'zdec') && isfield(cfg,'zdec_dashed') % ndata x nsmp x ndec
    zdec_dashed = cfg.zdec_dashed;
    ndata = size(zdec_dashed,1);
    nsmp = size(zdec_dashed,2);
end
if isfield(cfg,'xvec'), xvec = cfg.xvec;
else
    if isfield(cfg,'zdec')
        xvec = 1:size(cfg.zdec,2);
    end
end
if isfield(cfg,'rgb'),rgb = cfg.rgb;
else, rgb = lines; rgb = rgb(1:ndec,:);
end
if isfield(cfg,'rgb_dashed'),rgb_dashed = cfg.rgb_dashed;
else, rgb_dashed = rgb;
end
if isfield(cfg,'zdec')&&(ndec>size(rgb,1))
    rgb = cat(1,rgb,lines);
end


if isfield(cfg,'issubplot')
    if ~cfg.issubplot
        if isfield(cfg,'figname')
            figure('Color','white','Name',cfg.figname);
        else
            figure('Color','white');
        end
    end
else
    if isfield(cfg,'figname')
        figure('Color','white','Name',cfg.figname);
    else
        figure('Color','white');
    end
end

hold on

if isfield(cfg,'xlim'),xlim(cfg.xlim);
else
    xlim([min(xvec),max(xvec)]);
end

if isfield(cfg,'ylim'),ylim(cfg.ylim);
else
    ylim([-.025,0.4]);
end



if isfield(cfg,'stats0') && cfg.stats0 && isfield(cfg,'zdec') && ~use_tfce
    fprintf('computing permutations...\n')
    if isfield(cfg,'nres')
        nres = cfg.nres;
    else
        nres = 1e5;
    end
    if isfield(cfg,'alpha')
        alpha = cfg.alpha;
    else
        alpha = 0.05;
    end
    zdec = cfg.zdec;
    nsmp = size(zdec,2);
    ndec = size(zdec,3);
    for idec = 1:ndec
        [clusters, cluster_idx] = cluster_permutation(zdec(:,:,idec), xvec, nres, alpha, seed);
        stat.stats0(idec).clusters = clusters;
        for ic = 1:size(clusters,1)
            ctmp = cluster_idx{ic};
            pval = clusters(ic,3);
            if pval < alpha
                plot(xvec([min(ctmp) max(ctmp)]),max(ylim)*[1 1],'color',rgb(idec,:),'linewidth',1.5,'HandleVisibility', 'off')
            end
            fprintf('<strong>DATASET%d - Comparing cluster %d/%d - [%4.3f ; %4.3f] - :</strong>\n',idec,ic,size(clusters,1),xvec(min(ctmp)),xvec(max(ctmp)))
            fprintf('\tProportion of permuted tstat >= cluster tstat : pval = %5.4f\n',pval)
        end
    end
    fprintf('done.\n')
end

if isfield(cfg,'statsbetween') && cfg.statsbetween && isfield(cfg,'zdec') && size(cfg.zdec,3) == 2 && ~use_tfce
    fprintf('computing permuations...\n')
    if isfield(cfg,'nres')
        nres = cfg.nres;
    else
        nres = 1e5;
    end
    if isfield(cfg,'alpha')
        alpha = cfg.alpha;
    else
        alpha = 0.05;
    end
    zdec = cfg.zdec;
    nsmp = size(zdec,2);
    [clusters, cluster_idx] = cluster_permutation(zdec(:,:,1)-zdec(:,:,2), xvec, nres, alpha, seed);
    stat.statsbetween.clusters = clusters;
    for ic = 1:size(clusters,1)
        ctmp = cluster_idx{ic};
        pval = clusters(ic,3);
        if pval < alpha
            xvec_tmp = xvec(cluster_idx{ic});
            yvec = [mean(zdec(:,cluster_idx{ic},2)) fliplr(mean(zdec(:,cluster_idx{ic},1)))];
            patch([xvec_tmp fliplr(xvec_tmp)],yvec,[0.7 0.7 0.7],'FaceAlpha',0.5,'EdgeColor','none','HandleVisibility', 'off')
        end
        fprintf('<strong>DATASET1-DATASET2 - Comparing cluster %d/%d - [%4.3f ; %4.3f] :</strong>\n',ic,size(clusters,1),xvec(min(ctmp)),xvec(max(ctmp)))
        fprintf('\tProportion of permuted tstat >= cluster tstat : pval = %5.4f\n',pval)
    end
    fprintf('done.\n')
end


%% TFCE (cfg.statmethod = 'tfce'): same sign flips, p-value at each time point
if isfield(cfg,'zdec') && use_tfce && ((isfield(cfg,'stats0') && cfg.stats0) || (isfield(cfg,'statsbetween') && cfg.statsbetween && size(cfg.zdec,3) == 2))
    fprintf('computing permutations (TFCE)...\n')
    if isfield(cfg,'nres')
        nres = cfg.nres;
    else
        nres = 1e5;
    end
    if isfield(cfg,'alpha')
        alpha = cfg.alpha;
    else
        alpha = 0.05;
    end
    zdec = cfg.zdec;
    Ytest = {}; testname = {}; testtype = []; % 0: curve > 0, 1: curve 1 > curve 2
    if isfield(cfg,'stats0') && cfg.stats0
        for idec = 1:size(zdec,3)
            Ytest{end+1} = zdec(:,:,idec); testname{end+1} = sprintf('DATASET%d',idec); testtype(end+1) = 0; %#ok<AGROW>
        end
    end
    if isfield(cfg,'statsbetween') && cfg.statsbetween && size(zdec,3) == 2
        Ytest{end+1} = zdec(:,:,1)-zdec(:,:,2); testname{end+1} = 'DATASET1-DATASET2'; testtype(end+1) = 1;
    end
    for itest = 1:numel(Ytest)
        Ytru = Ytest{itest};
        [~,~,~,stats] = ttest(Ytru,0,'tail','right');
        tfce_tru = tfce_min2(stats.tstat, tfce_E, tfce_H, tfce_dh);
        % sign flips drawn once from a fixed seed (reproducible, and does not
        % change the global random stream)
        rs = RandStream('mt19937ar','Seed',seed);
        flips = 2*randi(rs,[0 1],nres,size(Ytru,1)) - 1;
        tfce_max = zeros(nres,1);
        parfor ires = 1:nres
            Yhat = flips(ires,:)'.*Ytru; % randomly assign -/+1
            [~,~,~,st] = ttest(Yhat,0,'tail','right');
            tfce_max(ires) = max(tfce_min2(st.tstat, tfce_E, tfce_H, tfce_dh));
        end
        p_t = (sum(tfce_max >= tfce_tru(:)', 1) + 1) / (nres + 1); % FWER-corrected p-value of each time point
        % windows of consecutive significant time points
        d = diff([0 p_t < alpha 0]);
        on = find(d == 1); off = find(d == -1) - 1;
        clusters = zeros(numel(on),3);
        for ic = 1:numel(on)
            ctmp = on(ic):off(ic);
            clusters(ic,:) = [xvec(on(ic)) xvec(off(ic)) min(p_t(ctmp))];
            if testtype(itest) == 0
                plot(xvec([on(ic) off(ic)]),max(ylim)*[1 1],'color',rgb(itest,:),'linewidth',1.5,'HandleVisibility', 'off')
            else
                xvec_tmp = xvec(ctmp);
                yvec = [mean(zdec(:,ctmp,2),1) fliplr(mean(zdec(:,ctmp,1),1))];
                patch([xvec_tmp fliplr(xvec_tmp)],yvec,[0.7 0.7 0.7],'FaceAlpha',0.5,'EdgeColor','none','HandleVisibility', 'off')
            end
            fprintf('<strong>%s - TFCE significant window %d/%d - [%4.3f ; %4.3f] :</strong>\n',testname{itest},ic,numel(on),xvec(on(ic)),xvec(off(ic)))
            fprintf('\tsmallest pval in the window = %5.4f\n',min(p_t(ctmp)))
        end
        if isempty(on)
            fprintf('<strong>%s - TFCE: no significant time point</strong> (smallest pval = %5.4f)\n',testname{itest},min(p_t))
        end
        if testtype(itest) == 0
            stat.stats0(itest).clusters = clusters;
            stat.stats0(itest).tfce_p = p_t;
        else
            stat.statsbetween.clusters = clusters;
            stat.statsbetween.tfce_p = p_t;
        end
    end
    fprintf('done.\n')
end


%% SHADED AREAS
% dashed lines
legend('AutoUpdate', 'off')
if isfield(cfg,'zdec_dashed')
    yavg_dashed  = mean(cfg.zdec_dashed,1);
    ndec_dashed = size(cfg.zdec_dashed,3);
    yerr_dashed =  std(cfg.zdec_dashed,[],1)/sqrt(size(cfg.zdec_dashed,1));
    yerr_vec = nan(2,nsmp,ndec_dashed);
    for idec = 1:ndec_dashed
        yerr_vec(1,:,idec) = yavg_dashed(1,:,idec) + yerr_dashed(1,:,idec);
        yerr_vec(2,:,idec) = yavg_dashed(1,:,idec) - yerr_dashed(1,:,idec);
        patch([xvec,fliplr(xvec)],[yerr_vec(1,:,idec),fliplr(yerr_vec(2,:,idec))], ...
            0.5*(rgb(idec,:)+1),'EdgeColor','none','HandleVisibility', 'off','FaceAlpha',0.5);
    end
end
% solid lines
if isfield(cfg,'zdec')
    yavg  = mean(cfg.zdec,1);
    ndec = size(cfg.zdec,3);
    yerr =  std(cfg.zdec,[],1)/sqrt(size(cfg.zdec,1));
    yerr_vec = nan(2,nsmp,ndec);
    for idec = 1:ndec
        yerr_vec(1,:,idec) = yavg(1,:,idec) + yerr(1,:,idec);
        yerr_vec(2,:,idec) = yavg(1,:,idec) - yerr(1,:,idec);
        patch([xvec,fliplr(xvec)],[yerr_vec(1,:,idec),fliplr(yerr_vec(2,:,idec))], ...
            0.5*(rgb(idec,:)+1),'EdgeColor','none','HandleVisibility', 'off','FaceAlpha',0.5);
    end
end

%% black lines
plot([0,0],ylim,'k','HandleVisibility', 'off');
plot(xlim,[0 0],'k','HandleVisibility', 'off');
    
%% mean zdec
if isfield(cfg,'zdec_dashed')
    yavg_dashed  = mean(cfg.zdec_dashed,1);
    for idec = 1:ndec_dashed
        plot(xvec,yavg_dashed(1,:,idec),'Color',rgb_dashed(idec,:),'LineWidth',lw,'LineStyle',':');
    end
end

if isfield(cfg,'zdec')
    yavg  = mean(cfg.zdec,1);
    for idec = 1:ndec
        plot(xvec,yavg(1,:,idec),'Color',rgb(idec,:),'LineWidth',lw);
    end
end

%%


if isfield(cfg,'legend')
    legend(cfg.legend);
else
    legend off
end
%%
if isfield(cfg,'ytick')
    set(gca,'YTick',cfg.ytick);
end
%%

%%
set(gca,'Layer','top','Box','off','TickDir','out','PlotBoxAspectRatio',[pbar,1,1]);

xlabel('time from stimulus onset (s)')
ylabel('decoding accuracy (z)')

helper_ILL(gcf,pbar,HGT,4.5);

if isfield(cfg,'saveornot') && isfield(cfg,'figname') && isfield(cfg,'figpath')
    if cfg.saveornot
        print(fullfile(cfg.figpath,cfg.figname),'-vector','-dpdf');
        fprintf('\nfigure %s saved in %s !\n',cfg.figname,cfg.figpath)
    end
end
        


function tfce_scores = tfce_min2(stat, E, H, dh)
% TFCE of a 1D statistic, as tfce_1d.m (sum over thresholds h = 0:dh:max of
% extent^E * h^H * dh), where a cluster has at least 2 samples
stat = stat(:)';
tfce_scores = zeros(size(stat));
for h = 0:dh:max(stat)
    d = diff([0 stat > h 0]);
    on = find(d == 1); off = find(d == -1) - 1;
    for c = 1:numel(on)
        extent = off(c) - on(c) + 1;
        if extent > 1
            tfce_scores(on(c):off(c)) = tfce_scores(on(c):off(c)) + (extent^E) * (h^H) * dh;
        end
    end
end
