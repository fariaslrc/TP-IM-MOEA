function [L,G] = x1_graph(RefN,legacyDistance,opt)
%X1_GRAPH Deterministic mutual-neighbour graph; isolated nodes are allowed.
% Ties use node index. No connectivity edges are invented across large gaps.
    n = size(RefN,1);
    if strcmp(opt.graphMode,'legacy')
        G = double(legacyDistance == 1);
        if ~opt.graphShuffled
            L = legacyDistance;
            return;
        end
    else
        G = zeros(n);
        dist = max(0,1-RefN*RefN');
        for j = 1:n
            idx = (1:n)'; idx(j) = [];
            [~,order] = sortrows([dist(j,idx)',idx],[1 2]);
            G(j,idx(order(1:min(opt.graphK,n-1)))) = 1;
        end
        G = double(G > 0 & G' > 0);
    end
    if opt.graphShuffled && n > 1
        old = rng;
        stream = RandStream('mt19937ar','Seed',mod(double(old.Seed)+104729,2^32-1));
        order = randperm(stream,n);
        G = G(order,order);
    end
    G(1:n+1:end) = 0;
    L = distances(graph(G > 0));
end
