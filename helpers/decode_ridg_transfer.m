function Chat_all = decode_ridg_transfer(x_trn, y_trn, x_tst, y_tst, fold_idx_trn, fold_idx_tst, alpha)
%  DECODE_RIDG_TRANSFER  Decode variable using ridge regression, training and
%  testing on two different sets of observations
%
%  Usage: Chat_all = DECODE_RIDG_TRANSFER(x_trn,y_trn,x_tst,y_tst,fold_idx_trn,fold_idx_tst,alpha)
%
%  where x_trn is the variable of the training set of size [n_trn,1]
%        y_trn is the data of the training set of size [n_trn,k,t]
%        x_tst is the variable of the testing set of size [n_tst,1]
%        y_tst is the data of the testing set of size [n_tst,k,t]
%        fold_idx_trn.trn{ifold} are the training observations of fold ifold
%        fold_idx_tst.tst{ifold} are the testing observations of fold ifold
%        alpha is the ridge regularization factor
%
%  k is the number of data features used for decoding and t the number of
%  time samples. At each time sample and for each fold, the decoder is trained
%  on observations fold_idx_trn.trn{ifold} of the training set and tested on
%  observations fold_idx_tst.tst{ifold} of the testing set. When both sets are
%  the same, this is the cross-validated decoding of DECODE_RIDG. The folds are
%  given by the caller (shuffled, same folds at every time sample).
%
%  Chat_all is the decoded value of the variable of size [n_tst,t].
%
%  Adapted from DECODE_RIDG by Valentin Wyart <valentin.wyart@ens.fr>
%  Modified by Julie Drevet, 2026:
%    * training and testing sets can differ (transfer decoding)
%    * data standardized w.r.t. the training observations of each fold
%    * decoding weights normalized by their 2-norm (wnorm = true), as in
%      DECODE_RIDG
%    * x_tst is not used for decoding (decoding accuracy computed by the caller)

% check input arguments
if nargin < 7
    error('Missing input arguments!');
end
if size(y_trn,1) ~= numel(x_trn) || size(y_tst,1) ~= numel(x_tst)
    error('Mismatching input sizes!');
end
if size(y_trn,2) ~= size(y_tst,2) || size(y_trn,3) ~= size(y_tst,3)
    error('Mismatching numbers of features or time samples between training and testing sets!');
end

% set internal parameters
wnorm = true; % normalize decoding weights by their 2-norm?

nfold       = numel(fold_idx_tst.tst);
ntrials_tst = size(y_tst, 1);
ntime       = size(y_trn, 3);

Chat_all = nan(ntrials_tst, ntime);

for ifold = 1:nfold
    idx_trn    = fold_idx_trn.trn{ifold};
    idx_tst    = fold_idx_tst.tst{ifold};
    y_trn_fold = y_trn(idx_trn,:,:);
    y_tst_fold = y_tst(idx_tst,:,:);
    x_trn_fold = x_trn(idx_trn);

    parfor itime = 1:ntime % parfor over time samples within each fold
        y_trn_t  = squeeze(y_trn_fold(:,:,itime));
        y_tst_t  = squeeze(y_tst_fold(:,:,itime));
        % standardize data w.r.t. training set
        trn_mean = mean(y_trn_t, 1);
        trn_std  = std(y_trn_t, [], 1);
        y_trn_z  = (y_trn_t - trn_mean) ./ trn_std;
        y_tst_z  = (y_tst_t - trn_mean) ./ trn_std;
        % compute decoding weights on training set
        W        = ridge(x_trn_fold, y_trn_z, alpha);
        if wnorm
            % normalize decoding weights by their 2-norm
            W    = W / sqrt(sum(W.^2));
        end
        % compute predictions on test set
        Chat_all(idx_tst, itime) = y_tst_z * W;
    end
end
end
