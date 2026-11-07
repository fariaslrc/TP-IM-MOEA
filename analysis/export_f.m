function export_f(block)
%EXPORT_F  Blocks F1 (WFG) and G2 (DTLZ), export_f('F1') or export_f('G2'): topology of the final map and accuracy of the
%prescreening, per run, from the instrumented runs (metric.protoW,
%protoHits, refN, instrLog). Only nodes trained at least once are used.
%   rhoTopo   Spearman correlation between the lattice distance (hops) and
%             the distance between decision-space prototypes, over node pairs
%   overlap   mean fraction of the lattice neighbors of a node that are among
%             its nearest nodes in decision space (as many as it has lattice
%             neighbors); overlapNull is its expected value for a random map
%   ratio     mean decision-space distance of adjacent pairs divided by that
%             of nonadjacent pairs (below 1: adjacent nodes are closer)
%   preRho, prec, precRand, impSel, impAll: means over the generations of the
%             prescreening log (rank correlation of predicted and true PBI;
%             precision of the selection against the true top B and its
%             random expectation; share of truly improving candidates among
%             the selected and among all candidates)
%Writes results/f_<block>.csv.

    here = fileparts(mfilename('fullpath'));
    [P,ISS] = repo_paths();       % PlatEMO, and the folder that holds the Data_<phase> folders
    if nargin < 1, block = 'F1'; end
    f = dir(fullfile(ISS,['Data_' block(1)],block,'**','*.mat'));
    f = f(~contains({f.folder},'_smoke'));
    n = numel(f);
    files = fullfile({f.folder},{f.name});
    cfg   = regexprep({f.folder},'.*[\\/]','');
    out   = nan(n,15); pname = cell(n,1); note = cell(n,1);
    parfor k = 1 : n
        S = load(files{k},'metric','cfg');
        c = S.cfg; m = S.metric;
        row = nan(1,15);
        row(1:5) = [c.M,c.D,c.run,m.IGDall,NaN];
        try
            M  = c.M;
            tr = m.protoHits(:) > 0;
            W  = m.protoW(tr,M+1:end);
            H  = RefGraph(m.refN,M); H = H(tr,tr);
            nT = sum(tr);
            Dx = squareform(pdist(W));
            up = triu(true(nT),1);
            rhoT = corr(H(up),Dx(up),'Type','Spearman');
            ov = nan(nT,1); ovn = nan(nT,1);
            for j = 1 : nT
                nb = find(H(j,:) == 1); kj = numel(nb);
                if kj == 0, continue; end
                d = Dx(j,:); d(j) = inf;
                [~,o] = sort(d);
                ov(j)  = numel(intersect(nb,o(1:kj)))/kj;
                ovn(j) = kj/(nT-1);
            end
            adj = H == 1 & up; non = H > 1 & up;
            row(5:9) = [nT,rhoT,mean(ov,'omitnan'),mean(ovn,'omitnan'),mean(Dx(adj))/mean(Dx(non))];
            L = m.instrLog;
            row(10:14) = mean(L(:,2:6),1,'omitnan');
            row(15) = size(L,1);
        catch err
            note{k} = err.message;
        end
        out(k,:) = row; pname{k} = c.probName;
    end
    fid = fopen(fullfile(fileparts(here),'results',['f_' block '.csv']),'w');
    fprintf(fid,'config,prob,M,D,run,IGDall,nTrained,rhoTopo,overlap,overlapNull,ratio,preRho,prec,impSel,impAll,precRand,nGen,note\n');
    for k = 1 : n
        fprintf(fid,'%s,%s,%d,%d,%d,%.10g,%d,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%.6g,%d,%s\n',cfg{k},pname{k},out(k,:),note{k});
    end
    fclose(fid);
    fprintf('wrote f_%s.csv (%d runs, %d with notes)\n',block,n,sum(~cellfun(@isempty,note)));
end

function LDis = RefGraph(RefN,M)
% Lattice of the reference-anchored map, as in TPIMMOEA_X: each direction is
% linked to its 2(M-1) angularly nearest directions (symmetrized), and the
% lattice distance is the hop count on this graph.
    n = size(RefN,1);
    k = min(n-1,max(2,2*(M-1)));
    Ang = acos(min(max(RefN*RefN',-1),1));
    Ang(logical(eye(n))) = inf;
    [~,I] = sort(Ang,2);
    A = false(n);
    for i = 1:n
        A(i,I(i,1:k)) = true;
    end
    A = A | A';
    LDis = distances(graph(A));
    finite = isfinite(LDis);
    LDis(~finite) = max(LDis(finite)) + 1;
end
