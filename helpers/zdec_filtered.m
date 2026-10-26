function zdec = zdec_filtered(A,B,ifilt)
%% zdec_filtered
% Decoding accuracy on a subset of tones (e.g. correct vs error sequences, or
% precise vs imprecise sound timing): Fisher z of the Pearson correlation between
% decoded and true values, at each time sample.
%   A      ntone x ntime, decoded values (out_dec.Chat)
%   B      ntone x 1, true values (out_dec.Ctru)
%   ifilt  ntone x 1 logical, tones to keep
%   zdec   1 x ntime, decoding accuracy (Fisher z)

r2z = @(r)0.5*log((1+r)./(1-r)); % fisher z transform

A = A(ifilt,:);
B = B(ifilt,:);
A_centered = A - mean(A, 1);
B_centered = B - mean(B, 1);
numerator = sum(A_centered .* B_centered, 1);
denominator = sqrt(sum(A_centered.^2, 1) .* sum(B_centered.^2, 1));
zdec = r2z(numerator ./ denominator);
