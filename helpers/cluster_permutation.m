function [clusters, cluster_idx] = cluster_permutation(Y, xvec, nres, alpha, seed)
% CLUSTER_PERMUTATION  One-sided cluster-based permutation test of Y > 0 over time
%
%  Usage: [clusters, cluster_idx] = cluster_permutation(Y, xvec, nres, alpha, seed)
%
%  where Y is the data of size [nparticipants, nsamples] (e.g. decoding accuracy, or the
%          difference between two decoding accuracies)
%        xvec is the time of each sample                            [default: 1:nsamples]
%        nres is the number of sign-flip permutations               [default: 1e5]
%        alpha is the cluster-forming threshold (one-tailed t-test) [default: 0.05]
%        seed is the seed of the sign flips                         [default: 1]
%
%  Clusters are runs of at least 2 consecutive samples with p < alpha (one-tailed
%  t-test against 0). The statistic of a cluster is its mass (sum of t-values). The null
%  distribution is the maximum cluster mass over the nres permutations, in which the sign
%  of each participant is flipped at random (the same flips at all samples). The flips are
%  drawn once from a fixed seed (reproducible, and the global random stream is unchanged).
%
%  clusters is [nclusters, 3]: [start time, end time, p-value] of each observed cluster,
%  with p = (number of permutations with a maximum mass >= observed mass + 1) / (nres + 1)
%  cluster_idx{ic} are the samples of cluster ic
%
%  Julie Drevet, 2026 (with claude)

if nargin < 2 || isempty(xvec), xvec = 1:size(Y,2); end
if nargin < 3 || isempty(nres), nres = 1e5; end
if nargin < 4 || isempty(alpha), alpha = 0.05; end
if nargin < 5 || isempty(seed), seed = 1; end

Ytru = Y;
% identify (true) clusters where zdec > 0
[h,~,~,stats]=ttest(Ytru,0,'tail','right','alpha',alpha);
c_tru = bwconncomp(h);
c_tru.PixelIdxList = c_tru.PixelIdxList(cellfun(@numel,c_tru.PixelIdxList) > 1); % a cluster has at least 2 samples
nc_tru = numel(c_tru.PixelIdxList);
cstat_tru = zeros(nc_tru,1);
for ic = 1:nc_tru
    cstat_tru(ic)= sum(stats.tstat(c_tru.PixelIdxList{ic}));
end

% sign flips drawn once from a fixed seed (reproducible, and does not
% change the global random stream)
rs = RandStream('mt19937ar','Seed',seed);
flips = 2*randi(rs,[0 1],nres,size(Ytru,1)) - 1;
cstat_res = zeros(nres,1);
% shuffle sign to get null distribution
parfor ires = 1:nres
    Yhat = flips(ires,:)'.*Ytru; % randomly assign -/+1
    [h,~,~,stats]=ttest(Yhat,0,'tail','right','alpha',alpha);
    c = bwconncomp(h);
    c.PixelIdxList = c.PixelIdxList(cellfun(@numel,c.PixelIdxList) > 1); % a cluster has at least 2 samples
    nc = numel(c.PixelIdxList);
    tstat_tmp = zeros(nc,1);
    for ic = 1:nc % same cluster definition as for the observed clusters
        tstat_tmp(ic)= sum(stats.tstat(c.PixelIdxList{ic}));
    end
    if ~isempty(tstat_tmp)
        cstat_res(ires) = max(tstat_tmp);
    end
end

% p-value of each observed cluster
clusters = zeros(numel(cstat_tru),3);
cluster_idx = c_tru.PixelIdxList;
for ic = 1:numel(cstat_tru)
    ctmp = c_tru.PixelIdxList{ic};
    pval = (sum(cstat_res >= cstat_tru(ic)) + 1) / (nres + 1);
    clusters(ic,:) = [xvec(min(ctmp)) xvec(max(ctmp)) pval];
end
end
