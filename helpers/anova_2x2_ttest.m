function stat = anova_2x2_ttest(x, names, label)
%% anova_2x2_ttest
% 2 x 2 repeated-measures ANOVA computed with paired t-tests: each effect is a
% paired t-test on a difference between conditions, with F(1,n-1) = t^2.
%   x      nsubj x 2 x 2 (dimension 2 = factor names{1}, dimension 3 = factor names{2})
%   names  names of the two factors, e.g. {'condition','precision'}
%   label  title of the printout (optional)
% Prints and returns stat(e), e = 1: main effect of names{1}, 2: main effect of
% names{2}, 3: interaction, with fields effect, F, df, p and bf10 (two-sided
% Bayes factor, bf.ttest).

if nargin < 3
    label = '';
end
if ndims(x) ~= 3 || size(x,2) ~= 2 || size(x,3) ~= 2
    error('x must be nsubj x 2 x 2!');
end

d = {mean(x(:,1,:),3) - mean(x(:,2,:),3), ...          % main effect of names{1}
     mean(x(:,:,1),2) - mean(x(:,:,2),2), ...          % main effect of names{2}
     (x(:,1,1) - x(:,2,1)) - (x(:,1,2) - x(:,2,2))};   % interaction
effect = {names{1}, names{2}, sprintf('%s x %s',names{1},names{2})};

if ~isempty(label)
    fprintf('%s\n', label);
end
fprintf('2 x 2 repeated-measures ANOVA (%s x %s, n = %d):\n', names{1}, names{2}, size(x,1));
stat = struct('effect',effect,'F',NaN,'df',NaN,'p',NaN,'bf10',NaN);
for e = 1:3
    [~,p,~,st] = ttest(d{e});
    stat(e).F  = st.tstat^2;
    stat(e).df = [1 st.df];
    stat(e).p  = p;
    stat(e).bf10 = bf.ttest(d{e});
    if p < 1e-4
        pstr = sprintf('%.1e',p);
    else
        pstr = sprintf('%.4f',p);
    end
    fprintf('\t%-*s F(1,%d) = %.3f, p = %s, BF10 = %.3f\n', max(cellfun(@numel,effect)), effect{e}, st.df, stat(e).F, pstr, stat(e).bf10);
end
end
