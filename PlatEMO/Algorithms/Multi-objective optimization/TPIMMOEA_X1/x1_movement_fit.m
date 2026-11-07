function model = x1_movement_fit(X,F,C,RefN,G,opt)
%X1_MOVEMENT_FIT Low-capacity field of observed, locally improving moves.
% X is normalized by the decision bounds. F uses ONE current ideal/nadir
% normalization for every row. No objective/constraint function is called.
%
% Pair construction is identical in every control: feasible observations in
% the same reference region, mutual moveNeighbors-nearest neighbours in X,
% distance <= movePairRadius (RMS), and strictly decreasing regional PBI.
% At most one better target is retained per source. This locality rule is a
% safeguard, not an identification or guarantee of inverse-model branches.
% Infeasible observations are excluded: constraint restoration is a separate
% mechanism, and objective progress must not reward increased violation.
%
% node: no sharing. global: one field. som: graph sharing in the fitted field
% AND its read-out. proximity: the same pipeline using regional decision
% centroids; the number of selected neighbours matches the supplied graph
% row where possible. shrink: no learned direction; apply only shrinks DE.
% Counts are descriptions of reused pairs, not independent sample sizes.
%
% Public model fields used by x1_movement_apply:
%   mode, nNodes, D, vectors (confidence-shrunk read-outs), support,
%   effectiveSupport, confidence, trainedVectors, readWeights.
% Diagnostic fields expose the common pair set, association and mixing.
% There are no random draws and no toolbox-dependent neighbour routines.

    validateattributes(X,{'numeric'},{'2d','real','finite'});
    validateattributes(F,{'numeric'},{'2d','real','finite'});
    validateattributes(RefN,{'numeric'},{'2d','real','finite'});
    n = size(X,1); d = size(X,2); nNodes = size(RefN,1);
    assert(d >= 1 && nNodes >= 1 && size(F,1) == n && ...
        size(F,2) == size(RefN,2),'X1:MovementShape','Incompatible X, F and RefN.');
    assert(all(X(:) >= -1e-10 & X(:) <= 1+1e-10), ...
        'X1:MovementBounds','X must use normalized decision bounds.');
    if isempty(C), C = zeros(n,0); end
    validateattributes(C,{'numeric'},{'2d','real','finite'});
    assert(size(C,1) == n,'X1:MovementShape','C must have one row per observation.');
    validateattributes(G,{'numeric','logical'},{'2d','real','finite','nonnegative'});
    assert(isequal(size(G),[nNodes,nNodes]),'X1:MovementShape','G must be nNodes by nNodes.');
    assert(max(abs(double(G(:))-reshape(double(G'),[],1))) < 1e-10 && ...
        all(abs(diag(double(G))) < 1e-10),'X1:MovementGraph','G must be symmetric with zero diagonal.');
    mode = char(opt.moveMode);
    assert(ismember(mode,{'none','node','global','som','proximity','shrink'}), ...
        'X1:MovementMode','Unknown movement mode.');
    validateattributes(opt.moveNeighbors,{'numeric'},{'scalar','integer','positive','finite'});
    validateattributes(opt.movePairRadius,{'numeric'},{'scalar','positive','finite'});
    validateattributes(opt.moveMinPairs,{'numeric'},{'scalar','integer','positive','finite'});
    validateattributes(opt.moveMinGain,{'numeric'},{'scalar','nonnegative','finite'});
    validateattributes(opt.moveSupportPrior,{'numeric'},{'scalar','positive','finite'});
    validateattributes(opt.moveTheta,{'numeric'},{'scalar','nonnegative','finite'});

    nr = sqrt(sum(RefN.^2,2));
    assert(all(nr > 0),'X1:MovementReference','Reference directions must be nonzero.');
    RefN = RefN./nr;
    dir = F./max(sqrt(sum(F.^2,2)),1e-12);
    [~,assoc] = max(dir*RefN',[],2);
    feasible = all(C <= 0,2);
    source = zeros(n,1); target = source; origin = source;
    gain = zeros(n,1); weight = gain; steps = zeros(n,d); np = 0;
    centroids = nan(nNodes,d);

    for j = 1:nNodes
        idx = find(assoc == j & feasible);
        if isempty(idx), continue; end
        centroids(j,:) = mean(X(idx,:),1);
        if numel(idx) < 2, continue; end
        XX = X(idx,:);
        dist = sqrt(max(0,sum(XX.^2,2)+sum(XX.^2,2)'-2*(XX*XX'))/d);
        dist(1:size(dist,1)+1:end) = inf;
        % Exact duplicates cannot provide a nonzero observed move.
        dist(dist <= 1e-12) = inf;
        near = false(size(dist));
        for a = 1:numel(idx)
            [dd,order] = sort(dist(a,:),'ascend');
            order = order(dd <= opt.movePairRadius);
            order = order(1:min(opt.moveNeighbors,numel(order)));
            near(a,order) = true;
        end
        near = near & near';
        proj = F(idx,:)*RefN(j,:)';
        score = proj + opt.moveTheta*sqrt(max(0,sum(F(idx,:).^2,2)-proj.^2));
        for a = 1:numel(idx)
            candidates = find(near(a,:) & ...
                (score' < score(a)-opt.moveMinGain*(1+abs(score(a)))));
            if isempty(candidates), continue; end
            % Largest observed local gain; equal scores retain index order.
            [~,b] = min(score(candidates)); b = candidates(b);
            np = np+1;
            source(np) = idx(a); target(np) = idx(b); origin(np) = j;
            gain(np) = score(a)-score(b);
            weight(np) = gain(np)/max(abs(score(a))+abs(score(b)),1e-12);
            steps(np,:) = X(idx(b),:)-X(idx(a),:);
        end
    end
    source = source(1:np); target = target(1:np); origin = origin(1:np);
    gain = gain(1:np); weight = weight(1:np); steps = steps(1:np,:);

    A = eye(nNodes);
    switch mode
        case 'global'
            A = ones(nNodes);
        case 'som'
            A = A + double(G);
        case 'proximity'
            active = find(all(isfinite(centroids),2));
            for j = active'
                candidate = active(active ~= j);
                if isempty(candidate), continue; end
                k = nnz(G(j,:) > 0);
                if k == 0, continue; end
                dd = sum((centroids(candidate,:)-centroids(j,:)).^2,2);
                [~,order] = sort(dd,'ascend');
                selected = candidate(order(1:min(k,numel(candidate))));
                % Keep the same off-diagonal row mass as the graph control.
                A(j,selected) = sum(G(j,:))/numel(selected);
            end
    end

    model = struct('mode',mode,'nNodes',nNodes,'D',d,'vectors',zeros(nNodes,d), ...
        'support',zeros(nNodes,1),'effectiveSupport',zeros(nNodes,1), ...
        'confidence',zeros(nNodes,1),'trainedVectors',zeros(nNodes,d), ...
        'readWeights',zeros(nNodes),'trainMix',A,'readMix',eye(nNodes), ...
        'association',assoc,'feasible',feasible,'centroids',centroids, ...
        'pairSource',source,'pairTarget',target,'pairOrigin',origin, ...
        'pairGain',gain,'pairWeight',weight,'pairStep',steps, ...
        'pairCount',np,'activeNodes',0,'coherence',zeros(nNodes,1));
    if np == 0, return; end

    % Each row is the actual coefficient of each original pair. Keeping this
    % representation avoids double-counting overlapping evidence at read-out.
    coefficients = A(:,origin).*weight';
    denom = sum(coefficients,2);
    coefficients = coefficients./max(denom,realmin);
    trainedSupport = sum(coefficients > 0,2);
    trainedESS = 1./max(sum(coefficients.^2,2),realmin);
    trainedESS(denom == 0) = 0;
    trainedConfidence = trainedESS./(trainedESS+opt.moveSupportPrior);
    trainedConfidence(trainedSupport < opt.moveMinPairs) = 0;
    model.trainedVectors = coefficients*steps;

    if ismember(mode,{'som','proximity'}), model.readMix = A; end
    readWeights = model.readMix.*trainedConfidence';
    readWeights = readWeights./max(sum(readWeights,2),realmin);
    combined = readWeights*coefficients;
    hasEvidence = sum(combined,2) > 0;
    model.support = sum(combined > 0,2);
    model.effectiveSupport = 1./max(sum(combined.^2,2),realmin);
    model.effectiveSupport(~hasEvidence) = 0;
    model.confidence = model.effectiveSupport./(model.effectiveSupport+opt.moveSupportPrior);
    model.confidence(model.support < opt.moveMinPairs) = 0;
    model.readWeights = readWeights;
    model.vectors = (readWeights*model.trainedVectors).*model.confidence;
    meanLength = combined*sqrt(sum(steps.^2,2));
    model.coherence = sqrt(sum((combined*steps).^2,2))./max(meanLength,realmin);
    model.coherence(~hasEvidence) = 0;
    model.activeNodes = nnz(model.confidence > 0 & sqrt(sum(model.vectors.^2,2)) > 1e-12);
end
