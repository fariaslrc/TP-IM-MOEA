function H = x1_cooperation_weights(hops,bmu,sigma,opt,confidence)
%X1_COOPERATION_WEIGHTS BMU stays 1; optional off-diagonal budget beta.
% Confidence is measured from direct BMU counts, not cooperative updates.
    H = zeros(size(hops));
    mask = isfinite(hops) & hops <= 3*sigma;
    H(mask) = exp(-hops(mask).^2/(2*sigma^2));
    H(bmu) = 0;
    if opt.supportWeights
        H = H .* sqrt(confidence(bmu)*confidence(:)');
    end
    if opt.massBudget >= 0 && sum(H) > 0
        H = opt.massBudget*H/sum(H);
    end
    H(bmu) = 1;
end
