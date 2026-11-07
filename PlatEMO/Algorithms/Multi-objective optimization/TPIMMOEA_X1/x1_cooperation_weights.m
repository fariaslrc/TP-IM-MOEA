function H = x1_cooperation_weights(hops,bmu,sigma,opt,confidence)
%X1_COOPERATION_WEIGHTS BMU stays 1; optional cap beta on the off-diagonal mass.
% The cap only shrinks: when the neighbours already receive less than beta in
% total, their Gaussian weights are kept (version 1 rescaled them up to beta, so
% a single neighbour could be trained as strongly as the winner).
% Confidence is measured from direct BMU counts, not cooperative updates.
    H = zeros(size(hops));
    mask = isfinite(hops) & hops <= 3*sigma;
    H(mask) = exp(-hops(mask).^2/(2*sigma^2));
    H(bmu) = 0;
    if opt.supportWeights
        H = H .* sqrt(confidence(bmu)*confidence(:)');
    end
    if opt.massBudget >= 0 && sum(H) > opt.massBudget
        H = opt.massBudget*H/sum(H);
    end
    H(bmu) = 1;
end
