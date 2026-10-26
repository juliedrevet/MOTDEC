function [out] = decode_ridg(C,D,nfold,alpha,sdtrn,corrtype,shuffleornot,seed)
%  DECODE_RIDG  Decode variable using ridge regression
%
%  Usage: [out] = DECODE_RIDG(C,D,nfold,alpha,sdtrn,corrtype,shuffleornot,seed)
%
%  where C is the variable of size [n,1]
%        D is the data matrix of size [n,k]
%        nfold is the number of cross-validation folds
%        alpha is the ridge regularization factor
%        sdtrn is the fold-wise data standardization flag (default=true)
%        corrtype is the correlation type (default='pearson')
%        shuffleornot is the observation shuffling flag (default=false)
%        seed is the seed of the shuffling (default=12345)
%
%  n is the number of observations, whereas k is the number of data features
%  used for decoding.
%
%  The output structure contains the following fields:
%    * Ctru is the ground-truth value of the variable
%    * Chat is the decoded value of the variable
%    * mhat is the fold-wise data mean
%    * shat is the fold-wise data s.d.
%    * What is the fold-wise decoding weight vector
%    * rdec is the decoding correlation coefficient
%    * Wdec is the overall decoding weight vector (without cross-validation)
%
%  Valentin Wyart <valentin.wyart@ens.fr>
%
%  Modified by Julie Drevet, 2026:
%    * shuffleornot and seed: when shuffleornot is true, the observations are
%      shuffled with rng(seed,'twister') before being split into folds (same
%      folds at every call with the same seed), and all outputs are returned
%      in the original order of the observations

% check input arguments
if nargin < 8
    seed = 12345;
end
if nargin < 7
    shuffleornot = false;
end
if nargin < 6
    corrtype = 'pearson';
end
if nargin < 5
    sdtrn = true;
end
if nargin < 4
    error('Missing input arguments!');
end
if size(C,2) > 1
    error('Cannot handle multiple regressors!');
end
if size(D,1) ~= size(C,1)
    error('Mismatching input sizes!');
end
if iscell(nfold) && shuffleornot
    error('Cannot shuffle observations with predefined training and test sets!');
end

% set internal parameters
wnorm = true; % normalize decoding weights by their 2-norm?

n = size(C,1); % number of observations
nfeat = size(D,2); % number of data features

% shuffle observations
if shuffleornot
    rng(seed,'twister'); % explicit generator: parallel workers default to threefry
    idx_shuffle = randperm(n);
    C = C(idx_shuffle);
    D = D(idx_shuffle,:);
end

% use or create training and test sets
if iscell(nfold)
    % use training and test sets
    itrn = nfold(:,1);
    itst = nfold(:,2);
    nfold = size(nfold,1);
    for ifold = 1:nfold
        itst{ifold} = itst{ifold}(:);
        itrn{ifold} = itrn{ifold}(:);
    end
else
    % create training and test sets
    itrn = cell(nfold,1);
    itst = cell(nfold,1);
    for ifold = 1:nfold
        itst{ifold} = find(mod((1:n)',nfold) == ifold-1);
        itrn{ifold} = find(mod((1:n)',nfold) ~= ifold-1);
    end
end

% get decoding set
idec = cat(1,itst{:});
if numel(unique(idec)) < numel(idec)
    error('Repeated observations found in decoding set!');
end

% perform decoding analysis
Chat = nan(n,1);
mhat = nan(nfold,nfeat);
shat = nan(nfold,nfeat);
What = nan(nfeat,nfold);
for ifold = 1:nfold
    Dhat = D;
    if sdtrn
        % standardize data w.r.t. training set
        mhat(ifold,:) = mean(D(itrn{ifold},:),1);
        shat(ifold,:) = std(D(itrn{ifold},:),[],1);
        Dhat = bsxfun(@minus,Dhat,mhat(ifold,:));
        Dhat = bsxfun(@rdivide,Dhat,shat(ifold,:));
    end
    % compute decoding weights on training set
    W = ridge(C(itrn{ifold}),Dhat(itrn{ifold},:),alpha);
    if wnorm
        % normalize decoding weights by their 2-norm
        W = W/sqrt(sum(W.^2));
    end
    % compute predictions on test set
    Chat(itst{ifold}) = Dhat(itst{ifold},:)*W;
    What(:,ifold) = W;
end

% restore original order of observations
if shuffleornot
    unshuffle_idx = zeros(n,1);
    unshuffle_idx(idx_shuffle) = 1:n; % inverse permutation
    C = C(unshuffle_idx);
    D = D(unshuffle_idx,:);
    Chat = Chat(unshuffle_idx);
end

% compute decoding correlation coefficient
rdec = corr(C(idec),Chat(idec),'type',corrtype);

% standardize data
D = zscore(D,[],1);
% compute overall decoding weights
Wdec = ridge(C(idec),D(idec,:),alpha);
if wnorm
    % normalize decoding weights by their 2-norm
    Wdec = Wdec/sqrt(sum(Wdec.^2));
end

% create output structure
out      = [];
out.Ctru = C;    % ground-truth value
out.Chat = Chat; % decoded value
out.mhat = mhat; % fold-wise data mean
out.shat = shat; % fold-wise data s.d.
out.What = What; % fold-wise decoding weights
out.rdec = rdec; % decoding correlation coefficient
out.Wdec = Wdec; % overall decoding weights

end
