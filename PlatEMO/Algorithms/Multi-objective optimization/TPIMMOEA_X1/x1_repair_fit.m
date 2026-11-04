function model = x1_repair_fit(X,C,assoc,G,opt)
%X1_REPAIR_FIT Learn individually scaled affine constraint models.
%   X contains chronological evaluated decisions in [0,1], C the complete
%   returned constraint vectors (feasible iff C <= 0), and assoc the source
%   node of each observation. G is a nonnegative symmetric adjacency matrix.
%   No objective/constraint function is called and no random number is drawn.
%
%   repairMode: 'none', 'global', 'proximity', or 'som'. Local pools have a
%   common target size max(minSamples,2*(D+1)); SOM grows in hop distance and
%   weights observations by path affinity, whereas proximity selects by the
%   distance to the observed regional centre. Disconnected SOM components
%   are never joined merely to obtain enough observations.
%
%   Validation holds out the latest 20% (at least five observations) of each
%   selected pool. Scale and fit are estimated on the earlier observations.
%   A model is used only when every constraint passes the normalized maximum
%   absolute holdout-error tolerance and both designs are full rank/well
%   conditioned. It is then refitted on the complete pool. This is evidence
%   of local adequacy, NOT a proof of global linearity or a calibrated bound.
%
%   Each item in model.global/model.local has: valid, coeff ((D+1)-by-L),
%   scale (1-by-L), margin (1-by-L), validationError, conditionTrain,
%   conditionFull, nTrain, nValidation, indices, weights, centre and reason.
%   coeff predicts C./scale from [ones X]; margin has the same scaled units.

    if nargin < 5, opt = struct(); end
    opt = defaults(opt);
    validateattributes(X,{'numeric'},{'real','2d'},mfilename,'X');
    validateattributes(C,{'numeric'},{'real','2d'},mfilename,'C');
    if size(C,1) ~= size(X,1)
        error('x1:repair:Rows','X and C must have the same number of rows.');
    end
    validateattributes(G,{'numeric','logical'},{'real','2d','nonempty','finite','nonnegative'},mfilename,'G');
    nNodes = size(G,1);
    if size(G,2) ~= nNodes || norm(double(G)-double(G'),inf) > 1e-10
        error('x1:repair:Graph','G must be a finite symmetric square adjacency matrix.');
    end
    assoc = assoc(:);
    if numel(assoc) ~= size(X,1) || any(~isfinite(assoc) | assoc < 1 | assoc > nNodes | assoc ~= fix(assoc))
        error('x1:repair:Association','assoc must contain one valid node index per observation.');
    end
    if any(X(isfinite(X)) < -1e-10 | X(isfinite(X)) > 1+1e-10)
        error('x1:repair:Domain','X must be normalized to [0,1].');
    end

    D = size(X,2); L = size(C,2);
    good = all(isfinite(X),2) & all(isfinite(C),2);
    originalIndices = find(good);
    X = X(good,:); C = C(good,:); assoc = assoc(good);
    X = min(1,max(0,double(X))); C = double(C);
    G = double(G); G(1:nNodes+1:end) = 0;
    minimum = max(D+6,ceil((D+1)/0.8));
    minimum = max(minimum,opt.repairMinSamples);
    empty = blank(D,L);
    model = struct('mode',opt.repairMode,'dimension',D,'nCons',L, ...
                   'nNodes',nNodes,'options',opt,'global',empty, ...
                   'local',{repmat({empty},nNodes,1)},'active',false(nNodes,1), ...
                   'nObservations',size(X,1),'nInvalid',sum(~good), ...
                   'minSamples',minimum,'targetSamples',max(minimum,2*(D+1)));
    if strcmp(opt.repairMode,'none') || L == 0 || D == 0
        return;
    end
    n = size(X,1);
    if strcmp(opt.repairMode,'global')
        item = fitOne(X,C,(1:n)',ones(n,1),originalIndices,minimum,opt);
        model.global = item;
        model.active(:) = item.valid;
        return;
    end

    for j = 1:nNodes
        own = assoc == j;
        if any(own)
            centre = mean(X(own,:),1);
        elseif n > 0
            centre = mean(X,1); % identical centre fallback for both controls
        else
            centre = zeros(1,D);
        end
        distance = sum((X-centre).^2,2);
        if strcmp(opt.repairMode,'som')
            [hop,affinity] = neighbourhood(G,j);
            reachable = find(isfinite(hop(assoc)));
            % Deterministic ties: hop, decision distance, chronological row.
            key = [hop(assoc(reachable)), distance(reachable), reachable];
            [~,order] = sortrows(key,[1 2 3]);
            idx = reachable(order(1:min(numel(order),model.targetSamples)));
            weight = max(1e-8,affinity(assoc(idx))./(1+hop(assoc(idx))));
        else
            [~,order] = sortrows([distance,(1:n)'],[1 2]);
            idx = order(1:min(n,model.targetSamples));
            weight = ones(numel(idx),1);
        end
        % Restore chronology before constructing the holdout.
        [idx,order] = sort(idx); weight = weight(order);
        item = fitOne(X,C,idx,weight,originalIndices,minimum,opt);
        item.centre = centre;
        model.local{j} = item;
        model.active(j) = item.valid;
    end
end

function item = fitOne(X,C,idx,weight,originalIndices,minimum,opt)
    D = size(X,2); L = size(C,2);
    item = blank(D,L);
    item.indices = originalIndices(idx);
    item.weights = weight;
    n = numel(idx);
    if n < minimum
        item.reason = 'insufficient_samples';
        return;
    end
    nVal = max(5,ceil(0.2*n));
    nTrain = n-nVal;
    item.nTrain = nTrain; item.nValidation = nVal;
    if nTrain < D+1
        item.reason = 'insufficient_training_samples';
        return;
    end
    A = [ones(n,1),X(idx,:)];
    Y = C(idx,:);
    tr = 1:nTrain; va = nTrain+1:n;
    % All scales are computed without the held-out constraint observations.
    scale = sqrt(mean(Y(tr,:).^2,1));
    scale = max(scale,1e-12);
    item.scale = scale;
    Y = Y./scale;
    rootWeight = sqrt(weight(:));
    At = A(tr,:).*rootWeight(tr);
    Yt = Y(tr,:).*rootWeight(tr);
    [ok,condition] = identifiable(At,opt.repairMaxCondition);
    item.conditionTrain = condition;
    if ~ok
        item.reason = 'unidentifiable_training_design';
        return;
    end
    coeff = At\Yt;
    residual = Y(va,:)-A(va,:)*coeff;
    item.validationError = max(abs(residual),[],1);
    if any(~isfinite(item.validationError)) || any(item.validationError > opt.repairTolerance)
        item.reason = 'validation_failed';
        return;
    end
    Af = A.*rootWeight;
    [ok,condition] = identifiable(Af,opt.repairMaxCondition);
    item.conditionFull = condition;
    if ~ok
        item.reason = 'unidentifiable_full_design';
        return;
    end
    coeff = Af\(Y.*rootWeight);
    if any(~isfinite(coeff(:)))
        item.reason = 'nonfinite_coefficients';
        return;
    end
    item.coeff = coeff;
    item.margin = opt.repairMargin*item.validationError + opt.repairNumericalMargin;
    % PlatEMO also represents unconstrained problems by an all-zero column.
    % A numerical margin must not invent a constant violation and launch a
    % QP for every candidate. Such a column supplies no repair direction.
    item.margin(all(Y == 0,1)) = 0;
    item.centre = mean(X(idx,:),1);
    item.valid = true;
    item.reason = 'validated';
end

function [ok,kappa] = identifiable(A,maxCondition)
    singular = svd(A,0);
    if numel(singular) < size(A,2) || isempty(singular) || singular(1) <= 0
        ok = false; kappa = inf; return;
    end
    tol = max(size(A))*eps(singular(1));
    if singular(end) <= tol
        ok = false; kappa = inf; return;
    end
    kappa = singular(1)/singular(end);
    ok = isfinite(kappa) && kappa <= maxCondition;
end

function [hop,affinity] = neighbourhood(G,j)
    n = size(G,1);
    hop = inf(n,1); hop(j) = 0;
    affinity = zeros(n,1); affinity(j) = 1;
    front = j;
    while ~isempty(front)
        next = zeros(1,0);
        for u = front
            for v = find(G(u,:) > 0)
                candidate = hop(u)+1;
                value = affinity(u)*min(1,G(u,v));
                if candidate < hop(v)
                    hop(v) = candidate; affinity(v) = value;
                    next(end+1) = v; %#ok<AGROW>
                elseif candidate == hop(v)
                    affinity(v) = max(affinity(v),value);
                end
            end
        end
        front = unique(next,'stable');
    end
end

function item = blank(D,L)
    item = struct('valid',false,'coeff',zeros(D+1,L),'scale',ones(1,L), ...
                  'margin',zeros(1,L),'validationError',inf(1,L), ...
                  'conditionTrain',inf,'conditionFull',inf,'nTrain',0, ...
                  'nValidation',0,'indices',zeros(0,1),'weights',zeros(0,1), ...
                  'centre',zeros(1,D),'reason','disabled');
end

function opt = defaults(opt)
    names = {'repairMode','repairRadius','repairTolerance','repairMinSamples', ...
             'repairPenalty','repairMargin','repairMaxCondition','repairNumericalMargin'};
    values = {'none',0.5,0.1,0,100,1,1e8,1e-8};
    for k = 1:numel(names)
        if ~isfield(opt,names{k}) || isempty(opt.(names{k}))
            opt.(names{k}) = values{k};
        end
    end
    opt.repairMode = validatestring(opt.repairMode,{'none','global','proximity','som'},mfilename,'repairMode');
    validateattributes(opt.repairRadius,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(opt.repairTolerance,{'numeric'},{'scalar','real','finite','nonnegative'});
    validateattributes(opt.repairMinSamples,{'numeric'},{'scalar','real','finite','integer','nonnegative'});
    validateattributes(opt.repairPenalty,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(opt.repairMargin,{'numeric'},{'scalar','real','finite','nonnegative'});
    validateattributes(opt.repairMaxCondition,{'numeric'},{'scalar','real','finite','>=',1});
    validateattributes(opt.repairNumericalMargin,{'numeric'},{'scalar','real','finite','nonnegative'});
end
