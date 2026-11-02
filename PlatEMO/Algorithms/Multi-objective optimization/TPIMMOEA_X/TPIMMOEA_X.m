classdef TPIMMOEA_X < ALGORITHM
% <2026> <multi/many> <real/integer> <constrained/none> <expensive>
% TPIMMOEA_X: research implementation of TP-IM-MOEA, used in every experiment
% of the article. The final algorithm is the configuration set by TPIMMOEA.m;
% the other switch values serve the ablation, the controls and the design study.
%
% numNodes  ---      --- number of SOM neurons (upper bound when lattice = 1; ignored when refMap = 1)
% eta0      --- 0.2  --- initial SOM learning rate
% sigma0    --- NaN  --- initial neighborhood radius (NaN: N for kernel 0, half the lattice diameter for kernel 1)
% batchSize --- 10   --- base batch size of real evaluations
% F         --- 0.5  --- base F for DE
% CR        --- 0.9  --- base CR for DE
% kernel    --- 0    --- 0: exp(-d) with hard cutoff; 1: Gaussian exp(-d^2/(2 sigma^2)), sigma decaying to 1
% lattice   --- 0    --- 0: 1-D chain; 1: min(M-1,3)-D grid
% gen       --- 0    --- 0: random ND parent; 1: isolation-biased parent + interpolation between lattice neighbours
% sel       --- 0    --- 0: NDSort + crowding distance; 1: NDSort + SPEA2-style truncation
% pre       --- 0    --- 0: no prescreening; K > 1: generate K*B candidates, evaluate the B best predicted
% preModel  --- 1    --- 1: SOM forward model; 2: kNN; 3: kNN if M <= 3, SOM otherwise; 4: mean of SOM and kNN; 5: Gaussian RBF; 6: topology-pooled local model (tps); 7: topology-pooled local Kriging (TP-LK, needs refMap)
% cheap     --- 0    --- 1: LHS initialisation, duplicate rejection and higher initial CR
% topo      --- 0    --- ablation of the topology: 0 none; 1 lattice positions shuffled once (fraction shufFrac of the nodes); 2 no neighborhood; 3 no SOM in reproduction; 4 no SOM in reproduction and no neighborhood
% refMap    --- 0    --- 1: the lattice is the simplex of reference directions (BMU by angle, neighborhood = adjacency between directions)
% niche     --- 0    --- 1 (needs refMap): half of the candidates fill empty niches by interpolating the occupied lattice neighbours
% infillD   --- 0    --- 1: prescreening by decomposition (one candidate per niche, predicted PBI improvement, empty niches first)
% selRef    --- 0    --- 1: for M >= 4, environmental selection by reference-direction niching
% shufFrac  --- 1    --- fraction of nodes shuffled when topo = 1 (dose-response of the topology)
% sigEnd    --- 1    --- final neighborhood radius of each training call (kernel 1)
% refTrain  --- 0    --- 1: train the map on the non-dominated archive members only
% lcb       --- 0    --- kappa of the lower-confidence-bound infill (infillD with preModel 7): PBI of mean - kappa*sd
% poolCtrl  --- 0    --- preModel 7 pooling: 0 map topology; 1 shuffled topology (shufFrac); 2 random pool of the same size; 3 no pooling (own node); 4 one global Kriging model
% knnK      --- 3    --- neighbours of the kNN predictor (objectives and constraint violation)
% pbiTheta  --- 5    --- penalty theta of the PBI score in the decomposition infill (infillD)
% Theta     --- 1000 --- evaluation budget above which the batch size is adapted
% outN      --- 0    --- 1: report N members chosen by the environmental selection instead of the 2N archive (search unchanged)
% anchorShuf --- 0   --- (refMap) fraction of the nodes whose anchors are permuted among themselves: a sample of region r
%                        trains node pi(r), while reproduction still reads the node of the parent's region
% instr     --- 0    --- 1: record the prototypes and the number of training hits per node (metric.protoW, protoHits,
%                        refN) and the accuracy of the prescreening on all candidates (metric.instrLog), computed with
%                        CalObj/CalCon, which spend no evaluation and draw no random number
% selMode   --- 0    --- (pre > 1) selection of the B evaluated candidates among the K*B generated: 0 prescreening;
%                        1 uniformly at random; 2 at random with at most one candidate per region of origin in a first
%                        pass (niche-stratified), without any prediction
% nbPhase   --- 0    --- (refMap) fraction of the epochs of each training call with a lattice neighbourhood (ordering
%                        phase, Gaussian radius from 1 to 0.5 hops); the remaining epochs update the winner only
% nbGlobal  --- 0    --- (refMap) fraction of the search budget with a lattice neighbourhood in every epoch, its radius
%                        falling linearly from 1 hop to 0 over that fraction; winner only afterwards
% reproNb   --- 0    --- use of the map neighbourhood in reproduction: 0 none; 1 base point drawn among the winner and
%                        its 2 nearest trained lattice neighbours; 2 second difference between the decision prototypes
%                        of those 2 neighbours; 3 second difference between 2 of the 5 archive members nearest to the
%                        base point in decision space; 4 both difference vectors drawn from those 5 archive members
% decBMU    --- 0    --- 1: training BMU by the decision part of the prototypes, reproduction reads the node with the
%                        nearest objective prototype (the anchors are not used by the map)
% etaGlobal --- 0    --- 1: the initial learning rate of each training call falls with the search progress, from eta0
%                        to 0.1*eta0
% The phase T switches above keep the lattice of training apart from LDis, so a training neighbourhood never
% activates interpolation or niche filling in reproduction, and they draw no random number when they are 0.

    methods
        function main(Algorithm,Problem)
            %% ---------------- PARAMETERS ----------------
            [numNodes,eta0,sigma0,batchBase,Fbase,CRbase,kernel,lattice,gen,sel,pre,preModel,cheap,topo, ...
             refMap,niche,infillD,selRef,shufFrac,sigEnd,refTrain,lcb,poolCtrl,knnK,pbiTheta,Theta,outN,anchorShuf,instr,selMode, ...
             nbPhase,nbGlobal,reproNb,decBMU,etaGlobal] = ...
                Algorithm.ParameterSet(Problem.N,0.2,NaN,10,0.5,0.9,0,0,0,0,0,1,0,0,0,0,0,0,1,1,0,0,0,3,5,1000,0,0,0,0, ...
                                       0,0,0,0,0);

            Npop = Problem.N;

            %% ---------------- INITIAL POPULATION ----------------
            if cheap
                Lo = Problem.lower; Up = Problem.upper;
                Population = Problem.Evaluation(repmat(Lo,Npop,1) + ...
                             lhsdesign(Npop,Problem.D).*repmat(Up-Lo,Npop,1));
            else
                Population = Problem.Initialization();
            end
            Archive = Population;

            M = Problem.M;

            %% ---------------- REFERENCE DIRECTIONS (deterministic) ----------------
            RefN = [];
            if refMap || infillD || selRef
                RefV = UniformPoint(Npop,M);
                RefN = RefV./max(vecnorm(RefV,2,2),1e-12);
            end
            niche = niche && refMap;

            if refMap
                %% ---------------- REFERENCE-ANCHORED MAP ----------------
                numNodes = size(RefN,1);
                W    = rand(numNodes, M + Problem.D);
                LDis = ReferenceGraph(RefN,M);
            else
                %% ---------------- LATTICE ----------------
                if lattice == 0
                    sides = floor(numNodes);
                else
                    L     = max(1,min(M-1,3));
                    sides = ones(1,L)*max(1,floor(numNodes^(1/L)));
                    grown = true;
                    while grown
                        grown = false;
                        for l = 1:L
                            s2 = sides; s2(l) = s2(l) + 1;
                            if prod(s2) <= numNodes
                                sides = s2; grown = true;
                            end
                        end
                    end
                end
                numNodes = prod(sides);

                %% ---------------- SOM INITIALIZATION ----------------
                % W = [Fnorm | Xnorm]
                W = rand(numNodes, M + Problem.D);

                Dlat = arrayfun(@(S)1:S,sides,'UniformOutput',false);
                eval(sprintf('[%s]=ndgrid(Dlat{:});',sprintf('c%d,',1:length(Dlat))))
                eval(sprintf('V=[%s];',sprintf('c%d(:),',1:length(Dlat))))
                LDis = pdist2(V,V);
            end

            if isnan(sigma0)
                if kernel == 0
                    sigma0 = Problem.N;
                else
                    sigma0 = max(1,max(LDis(:))/2);
                end
            end

            % Topology ablation (after sigma0, so the radius schedule is unchanged)
            if topo == 1
                if shufFrac >= 1
                    perm = randperm(numNodes);
                else
                    perm = 1:numNodes;
                    S    = randperm(numNodes,round(shufFrac*numNodes));
                    perm(S) = S(randperm(numel(S)));
                end
                LDis = LDis(perm,perm);
            elseif topo == 2 || topo == 4
                LDis(LDis > 0) = inf;
            end

            if refMap, RefBMU = RefN; else, RefBMU = []; end
            % Shuffled anchors: node pi(r) is trained on region r (RefBMU(pi(r),:) = RefN(r,:)),
            % reproduction still reads node r. No random number is drawn when anchorShuf = 0.
            if refMap && anchorShuf > 0
                piA = 1:numNodes;
                S   = randperm(numNodes,max(2,round(anchorShuf*numNodes)));
                piA(S) = S(randperm(numel(S)));
                RefBMU(piA,:) = RefN;
            end
            protoHits = zeros(numNodes,1);
            somQE = inf;

            % Topology-pooled local Kriging (TP-LK): pooling graph = the
            % reference graph of the map, kept apart from the training
            % neighbourhood, so the training ablations (topo) do not
            % change it. The pooling controls act on this graph only.
            kc = struct('lcb',lcb,'poolCtrl',poolCtrl,'knnK',knnK,'pbiTheta',pbiTheta);
            if preModel == 7 && refMap
                kc.LDisTrue  = ReferenceGraph(RefN,M);
                kc.LDisPool  = kc.LDisTrue;
                if poolCtrl == 1
                    if shufFrac >= 1
                        pp = randperm(numNodes);
                    else
                        pp = 1:numNodes;
                        S  = randperm(numNodes,round(shufFrac*numNodes));
                        pp(S) = S(randperm(numel(S)));
                    end
                    kc.LDisPool = kc.LDisTrue(pp,pp);
                end
                kc.thetaNode = 5*ones(numNodes,Problem.D);
                kc.thetaGlob = 5*ones(1,Problem.D);
            end

            % Phase T: lattice of training (apart from LDis) and the nodes trained so far
            tc = struct('LDisTrain',[],'nbPhase',nbPhase,'nbGlobal',nbGlobal,'decBMU',decBMU, ...
                        'etaGlobal',etaGlobal,'search',0);
            if refMap && (nbPhase > 0 || nbGlobal > 0)
                tc.LDisTrain = ReferenceGraph(RefN,M);
            end
            trained = false(numNodes,1);
            kc.reproNb = reproNb; kc.decBMU = decBMU;

            %% ---------------- MAIN LOOP ----------------
            while Algorithm.NotTerminated(ReportSet(Archive,outN,Npop,M,sel,selRef,RefN))

                progress = Problem.FE / Problem.maxFE;

                Fobjs = Archive.objs;
                ideal = min(Fobjs,[],1);
                nadir = max(Fobjs,[],1);

                %% 1) Train inverse SOM
                TrainSet = Archive;
                if refTrain
                    FN = NDSort(Archive.objs,Archive.cons,1);
                    if sum(FN == 1) >= 3
                        TrainSet = Archive(FN == 1);
                    end
                end
                tc.search = max(0,(Problem.FE - Npop)/max(Problem.maxFE - Npop,1));
                [W,somQE,hitNow] = TrainInverseSOM_X(Problem,W,LDis,TrainSet, ...
                                              numNodes,eta0,sigma0,ideal,nadir,kernel,RefBMU,sigEnd,tc);
                trained = trained | hitNow;
                kc.trained = trained;
                if instr && refMap
                    Ft = (TrainSet.objs - ideal)./(nadir - ideal + 1e-12);
                    [~,hit] = max((Ft./max(vecnorm(Ft,2,2),1e-12))*RefBMU',[],2);
                    protoHits = protoHits + accumarray(hit,1,[numNodes 1]);
                    Algorithm.metric.protoW    = W;      % overwritten every generation: the last value is saved
                    Algorithm.metric.protoHits = protoHits;
                    Algorithm.metric.refN      = RefN;
                end
                kc.instr = instr; kc.selMode = selMode;

                %% 1.1) Adaptive batch size (progress + SOM quantization error)
                batchEff = batchBase;
                if Problem.maxFE > Theta
                    accScore   = 1/(1 + max(somQE,0));
                    progScore  = sqrt(max(progress,0));
                    adaptScore = min(1, max(accScore,progScore));

                    minBatch = batchBase;
                    maxBatch = Npop;
                    batchEff = round(minBatch + (maxBatch-minBatch)*adaptScore);
                end

                remainingFE = Problem.maxFE - Problem.FE;
                batchEff    = max(1,min(batchEff,remainingFE));

                %% 2) Offspring generation
                [Offspring,predLog,kc] = OperatorInverseDE_X(Problem,Archive,W,LDis,batchEff, ...
                                                ideal,nadir,Fbase,CRbase,progress, ...
                                                gen,pre,preModel,cheap,topo,RefN,refMap,niche,infillD,kc);
                if ~isempty(predLog)
                    if isfield(Algorithm.metric,'predLog')
                        Algorithm.metric.predLog(end+1,:) = predLog;
                    else
                        Algorithm.metric.predLog = predLog;
                    end
                end
                if instr && isfield(kc,'instrRow') && ~isempty(kc.instrRow)
                    if isfield(Algorithm.metric,'instrLog')
                        Algorithm.metric.instrLog(end+1,:) = [Problem.FE, kc.instrRow];
                    else
                        Algorithm.metric.instrLog = [Problem.FE, kc.instrRow];
                    end
                    kc.instrRow = [];
                end

                %% 3) Elitist archive update
                Archive = [Archive,Offspring];
                MaxArc  = 2*Npop;
                K       = min(MaxArc,length(Archive));

                if selRef && M >= 4
                    Archive = RefNicheSelection(Archive,K,RefN);
                elseif sel == 0
                    [FrontNo,MaxFNo] = NDSort(Archive.objs,Archive.cons,K);
                    Next = FrontNo < MaxFNo;

                    CrowdDis = CrowdingDistance(Archive.objs,FrontNo);
                    Last     = find(FrontNo==MaxFNo);
                    [~,Rank] = sort(CrowdDis(Last),'descend');

                    slots = K - sum(Next);
                    slots = min(slots,length(Last));
                    if slots > 0
                        Next(Last(Rank(1:slots))) = true;
                    end
                    Archive = Archive(Next);
                else
                    Archive = TruncationSelection(Archive,K);
                end

                if length(Archive) > Npop
                    Population = Archive(1:Npop); %#ok<NASGU>
                else
                    Population = Archive; %#ok<NASGU>
                end
            end
        end
    end
end

%% =================== REPORTED SET ===================
function P = ReportSet(Archive,outN,N,M,sel,selRef,RefN)
% Set handed to PlatEMO for recording. With outN = 1 it holds N members
% chosen by the same environmental selection that maintains the archive
% (reference niching for M >= 4 with selRef, truncation with sel = 1), so
% that the method reports a population of size N like the baselines.
    if ~outN || length(Archive) <= N
        P = Archive;
    elseif selRef && M >= 4
        P = RefNicheSelection(Archive,N,RefN);
    elseif sel == 1
        P = TruncationSelection(Archive,N);
    else
        error('TPIMMOEA_X:outN','outN = 1 requires sel = 1 or selRef = 1.');
    end
end

%% =================== REFERENCE GRAPH ===================

function LDis = ReferenceGraph(RefN,M)
% Lattice of the reference-anchored map: each direction is linked to its
% 2(M-1) angularly nearest directions (symmetrized), and the lattice
% distance is the hop count on this graph. On a single-layer simplex this
% reproduces the adjacency between neighbouring regions of the front.

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

%% =================== SOM INVERSE TRAINING ===================

function [W,qe,hit] = TrainInverseSOM_X(Problem,W,LDis,Samples, ...
                                    numNodes,eta0,sigma0,ideal,nadir,kernel,RefBMU,sigEnd,tc)
% kernel 0: weight exp(-d) inside the hard radius sigma.
% kernel 1: Gaussian weight exp(-d^2/(2 sigma^2)), sigma decaying
%           geometrically from sigma0 to sigEnd within each training call.
% RefBMU non-empty (refMap): the BMU of a sample is the node whose fixed
% reference direction makes the smallest angle with the sample's
% normalized objective vector.
% tc (phase T): tc.decBMU = 1 takes the BMU by the decision part of the
% prototypes; tc.nbPhase or tc.nbGlobal > 0 add a Gaussian neighbourhood on
% tc.LDisTrain (ordering phase), winner only otherwise; tc.etaGlobal = 1
% scales eta0 by 0.1 + 0.9(1 - search progress). hit: nodes updated with a
% weight of at least 0.05.

    hit = false(size(W,1),1);
    if nargin < 13, tc = []; end
    if isempty(Samples)
        qe = inf;
        return;
    end
    decB = ~isempty(tc) && tc.decBMU;
    useT = ~isempty(tc) && ~isempty(tc.LDisTrain);
    etaScale = 1;
    if ~isempty(tc) && tc.etaGlobal
        etaScale = 0.1 + 0.9*(1 - tc.search);
    end

    M = Problem.M;
    D = Problem.D;

    X = Samples.decs;
    F = Samples.objs;

    Xnorm = rescale(X,'InputMin',Problem.lower,'InputMax',Problem.upper);
    Fnorm = (F - repmat(ideal,size(F,1),1)) ./ ...
            (repmat(nadir-ideal,size(F,1),1) + 1e-12);

    Data = [Fnorm, Xnorm];
    nS   = size(Data,1);

    if size(W,1) ~= numNodes || size(W,2) ~= (M+D)
        W = rand(numNodes,M+D);
    end

    if ~isempty(RefBMU)
        [~,bmuRef] = max((Fnorm./max(vecnorm(Fnorm,2,2),1e-12))*RefBMU',[],2);
    end

    nEpoch = 20;
    for epoch = 1:nEpoch
        if kernel == 0
            sigma = sigma0 * exp(-epoch/nEpoch);
        else
            sigma = sigma0 * (sigEnd/sigma0)^((epoch-1)/(nEpoch-1));
        end
        eta = etaScale * eta0 * exp(-epoch/nEpoch);
        sigT = 0;                                 % phase T radius on LDisTrain (0: not used)
        if useT
            if tc.nbPhase > 0
                nPh = max(1,round(tc.nbPhase*nEpoch));
                if epoch <= nPh
                    sigT = 0.5^((epoch-1)/max(nPh-1,1));
                end
            elseif tc.nbGlobal > 0 && tc.search < tc.nbGlobal
                sigT = 1 - tc.search/tc.nbGlobal;
            end
        end

        order = randperm(nS);
        for t = 1:nS
            s = order(t);
            y = Data(s,1:M);
            x = Data(s,M+1:end);

            if decB
                % BMU computed on the decision part of the prototypes
                [~,bmu] = min(pdist2(x,W(:,M+1:end)));
            elseif isempty(RefBMU)
                % BMU computed on objectives only
                [~,bmu] = min(pdist2(y,W(:,1:M)));
            else
                bmu = bmuRef(s);
            end

            if sigT > 0
                U = tc.LDisTrain(bmu,:) <= 3*sigT;
                H = exp(-tc.LDisTrain(bmu,U).^2/(2*sigT^2));
            elseif kernel == 0
                U = LDis(bmu,:) < sigma;
                if ~any(U)
                    U(bmu) = true;
                end
                H = exp(-LDis(bmu,U));
            else
                U = LDis(bmu,:) <= 3*sigma;
                H = exp(-LDis(bmu,U).^2/(2*sigma^2));
            end
            H = H(:);

            W(U,1:M)     = W(U,1:M)     + eta*(H .* (y - W(U,1:M)));
            W(U,M+1:end) = W(U,M+1:end) + eta*(H .* (x - W(U,M+1:end)));
            hit(U) = hit(U) | (H >= 0.05);
        end
    end

    W(:,M+1:end) = min(max(W(:,M+1:end),0),1);

    Dist = pdist2(Fnorm,W(:,1:M));
    qe   = mean(min(Dist,[],2));
end

%% =================== OFFSPRING GENERATION ===================

function [Offspring,predLog,kc] = OperatorInverseDE_X(Problem,Archive,W,LDis,batchSize, ...
                                         ideal,nadir,Fbase,CRbase,progress, ...
                                         gen,pre,preModel,cheap,topo,RefN,refMap,niche,infillD,kc)
% gen 0: random ND parent -> BMU -> prototype.
% gen 1: ND parent drawn with probability proportional to its isolation in
%        objective space -> BMU j -> base point interpolated or
%        extrapolated towards a random lattice neighbour k of j.
% niche (refMap): with probability 0.5, an empty niche j (a direction with
%        no non-dominated solution) is targeted; its base point mixes the
%        prototype of j with the barycentre of the real solutions of the
%        occupied lattice neighbours of j (hop <= 2, weights 1/hop).
% In all cases the base point is refined by the adaptive DE of TPIMMOEA.
% pre > 1: pre*batchSize candidates are generated and the batchSize best
%          predicted ones are evaluated (see Prescreen). predLog records
%          [FE, mean Spearman(predicted, true), mean absolute error] of
%          the evaluated candidates (normalized objectives).

    M    = Problem.M;
    D    = Problem.D;
    nArc = length(Archive);
    predLog = [];

    Lower = Problem.lower(:)';
    Upper = Problem.upper(:)';
    Range = max(Upper - Lower,eps);

    if nArc < 3
        OffDec = unifrnd(repmat(Lower,batchSize,1),repmat(Upper,batchSize,1));
        Offspring = Problem.Evaluation(OffDec);
        return;
    end

    Fobjs = Archive.objs;
    C     = Archive.cons;
    [FrontNo,~] = NDSort(Fobjs,C,inf);
    NDidx = find(FrontNo == 1);
    if isempty(NDidx)
        NDidx = 1:nArc;
    end
    ND  = Archive(NDidx);
    nND = length(ND);

    Fnd   = ND.objs;
    Fnorm = (Fnd - repmat(ideal,nND,1)) ./ ...
            (repmat(nadir-ideal,nND,1) + 1e-12);

    SomY = W(:,1:M);
    SomX = W(:,M+1:end);
    ArcDec = Archive.decs;

    % Phase T: neighbourhood of the map in reproduction (kc.reproNb) and the
    % reading rule of DecisionSOM (kc.decBMU); nothing is computed when both are 0
    rNb  = isfield(kc,'reproNb') && kc.reproNb > 0;
    decR = isfield(kc,'decBMU')  && kc.decBMU  > 0;
    if rNb && any(kc.reproNb == [1 2]) && refMap
        % the 2 nearest trained nodes among the lattice neighbours of each node
        nNode  = size(RefN,1);
        CosRef = RefN*RefN';
        CosRef(1:nNode+1:end) = -inf;
        [~,Ord] = sort(CosRef,2,'descend');
        Ord  = Ord(:,1:min(nNode-1,max(2,2*(M-1))));
        NbTr = cell(nNode,1);
        for jj = 1:nNode
            o = Ord(jj,:);
            if isfield(kc,'trained'), o = o(kc.trained(o)); end
            NbTr{jj} = o(1:min(2,numel(o)));
        end
    end
    if rNb && any(kc.reproNb == [3 4])
        ArcNorm = (ArcDec - Lower)./Range;
        kN = min(5,nArc);
    end

    if gen == 1
        if nND > 1
            Dn = pdist2(Fnorm,Fnorm);
            Dn(logical(eye(nND))) = inf;
            iso = min(Dn,[],2);
        else
            iso = 1;
        end
        if sum(iso) > 0 && all(isfinite(iso))
            cumP = cumsum(iso(:)')/sum(iso);
        else
            cumP = (1:nND)/nND;
        end
        Nbr = LDis <= 1 + 1e-9 & LDis > 0;
    end

    if refMap
        FnDir = Fnorm./max(vecnorm(Fnorm,2,2),1e-12);
        [~,assocND] = max(FnDir*RefN',[],2);
    end
    emptyN = [];
    if niche
        nNodes   = size(RefN,1);
        occupied = accumarray(assocND,1,[nNodes 1])' > 0;
        emptyN   = find(~occupied);
        d1  = sum(Fnorm.*RefN(assocND,:),2);
        d2  = sqrt(max(sum(Fnorm.^2,2) - d1.^2,0));
        rep = zeros(1,nNodes);
        for j = find(occupied)
            members = find(assocND == j);
            [~,b]   = min(d2(members));
            rep(j)  = members(b);
        end
        NDXn = (ND.decs - Lower)./Range;
    end

    nCand = batchSize;
    if pre > 1
        nCand = round(pre*batchSize);
    end
    OffDec   = zeros(nCand,D);
    candNode = zeros(nCand,1);      % map region each candidate was generated for (refMap)

    for i = 1:nCand
        tries = 0;
        while true
            useNiche = false;
            srcNode  = 0;
            if niche && ~isempty(emptyN) && rand < 0.5
                j     = emptyN(randi(numel(emptyN)));
                nbOcc = find(LDis(j,:) <= 2 & occupied);
                if ~isempty(nbOcc)
                    w    = 1./LDis(j,nbOcc); w = w/sum(w);
                    bary = w*NDXn(rep(nbOcc),:);
                    if topo == 3 || topo == 4
                        xProtoNorm = bary;
                    else
                        a = rand;
                        xProtoNorm = a*SomX(j,:) + (1-a)*bary;
                    end
                    useNiche = true;
                    srcNode  = j;
                end
            end
            if ~useNiche
                if gen == 0
                    idxP = randi(nND);
                    yP   = Fnorm(idxP,:);
                    if refMap
                        bmu = assocND(idxP);
                        srcNode = bmu;
                    else
                        [~,bmu] = min(pdist2(yP,SomY));
                    end
                    xProtoNorm = SomX(bmu,:);
                else
                    idxP = find(rand <= cumP,1);
                    if isempty(idxP), idxP = nND; end
                    yP = Fnorm(idxP,:);
                    if refMap
                        j = assocND(idxP);
                        srcNode = j;
                    else
                        [~,j] = min(pdist2(yP,SomY));
                    end
                    if decR
                        % DecisionSOM: read the node with the nearest objective prototype
                        [~,j] = min(pdist2(yP,SomY));
                        srcNode = j;
                    end
                    nb = find(Nbr(j,:));
                    if isempty(nb)
                        xProtoNorm = SomX(j,:);
                    else
                        k   = nb(randi(numel(nb)));
                        lam = -0.25 + 1.5*rand;
                        xProtoNorm = SomX(j,:) + lam*(SomX(k,:) - SomX(j,:));
                    end
                    if rNb && kc.reproNb == 1 && refMap && ~isempty(NbTr{j})
                        % base point drawn among the winner and its 2 nearest trained neighbours
                        c = randi(numel(NbTr{j}) + 1);
                        if c > 1, xProtoNorm = SomX(NbTr{j}(c-1),:); end
                    end
                end
                if topo == 3 || topo == 4
                    % No SOM in reproduction: base point = the parent itself
                    xProtoNorm = (ND(idxP).dec(:)' - Lower)./Range;
                end
            end
            xProtoNorm = min(max(xProtoNorm,0),1);

            xProto = xProtoNorm .* (Upper - Lower) + Lower;
            xProto = xProto(:)';

            idx = randperm(nArc,2);
            X1  = ArcDec(idx(1),:);
            X2  = ArcDec(idx(2),:);
            extra = [];                           % phase T second difference
            if rNb
                switch kc.reproNb
                    case 2      % between the decision prototypes of 2 trained neighbours of the region
                        if refMap && srcNode > 0 && numel(NbTr{srcNode}) == 2
                            nbj = NbTr{srcNode};
                            if rand < 0.5, nbj = nbj([2 1]); end
                            extra = (SomX(nbj(1),:) - SomX(nbj(2),:)) .* Range;
                        end
                    case {3,4}  % among the archive members nearest to the base point in decision space
                        [~,nn] = sort(sum((ArcNorm - xProtoNorm).^2,2));
                        pick = nn(randperm(kN,2));
                        if kc.reproNb == 3
                            extra = ArcDec(pick(1),:) - ArcDec(pick(2),:);
                        else
                            X1 = ArcDec(pick(1),:); X2 = ArcDec(pick(2),:);
                        end
                end
            end

            F_adapt = 0.8 - 0.4*progress;
            if cheap
                CR_adapt = 0.6 + 0.3*progress;
            else
                CR_adapt = 0.2 + 0.6*progress;
            end

            F_loc  = max(0.1,min(1.0,0.5*(Fbase  + F_adapt)));
            CR_loc = max(0.0,min(1.0,0.5*(CRbase + CR_adapt)));

            v = xProto + F_loc .* (X1 - X2);
            if ~isempty(extra)
                v = v + 0.5*F_loc .* extra;
            end
            v = min(max(v,Lower),Upper);

            jrand = randi(D);
            mask  = (rand(1,D) <= CR_loc);
            mask(jrand) = true;

            u = xProto;
            u(mask) = v(mask);
            u = min(max(u,Lower),Upper);

            if ~cheap || tries >= 5 || ~IsDuplicate(u,[ArcDec;OffDec(1:i-1,:)],Range)
                break;
            end
            tries = tries + 1;
        end
        OffDec(i,:)  = u;
        candNode(i)  = srcNode;
    end

    if pre > 1
        kc.candNode = candNode;
        if isfield(kc,'selMode') && kc.selMode > 0
            % Controls of the prescreening: random selection from the same pool,
            % optionally one candidate per region of origin first (no prediction)
            order = randperm(nCand);
            if kc.selMode == 2
                [~,first] = unique(candNode(order),'stable');
                order = order([first(:)', setdiff(1:nCand,first,'stable')]);
            end
            chosen  = order(1:min(batchSize,nCand));
            PredSel = zeros(numel(chosen),M); SdSel = PredSel;
        else
            [chosen,PredSel,SdSel,kc] = Prescreen(Problem,Archive,W,LDis,OffDec,batchSize,ideal,nadir, ...
                                                  preModel,RefN,infillD,kc);
        end
        OffDec = OffDec(chosen,:);
    end

    Offspring = Problem.Evaluation(OffDec);

    if pre > 1 && numel(Offspring) >= 3
        TrueN = (Offspring.objs - ideal)./(nadir - ideal + 1e-12);
        rho   = nan(1,M);
        for m = 1:M
            if std(PredSel(:,m)) > 0 && std(TrueN(:,m)) > 0
                rho(m) = corr(PredSel(:,m),TrueN(:,m),'Type','Spearman');
            end
        end
        % coverage of the +-2 sd interval (only for models with uncertainty)
        hasSd = SdSel > 0;
        cover = NaN;
        if any(hasSd(:))
            cover = mean(abs(TrueN(hasSd) - PredSel(hasSd)) <= 2*SdSel(hasSd));
        end
        predLog = [Problem.FE, mean(rho,'omitnan'), mean(abs(PredSel(:) - TrueN(:))), cover, mean(SdSel(:))];
    end
end

function dup = IsDuplicate(u,P,Range)
    if isempty(P)
        dup = false;
    else
        dup = any(all(abs(P - u) <= 1e-6*Range,2));
    end
end

%% =================== PRESCREENING (FORWARD MODEL) ===================

function [chosen,PredSel,SdSel,kc] = Prescreen(Problem,Archive,W,LDis,Cand,B,ideal,nadir,preModel,RefN,infillD,kc)
% Predicts the normalized objectives of every candidate without spending
% evaluations and picks B of them. Constraint violations are always
% predicted by inverse-distance kNN on the archive.
%   preModel 1: SOM forward model (3 nearest prototypes in decision space).
%   preModel 2: kNN (3 nearest archive members in decision space).
%   preModel 3: kNN when M <= 3, SOM forward model otherwise.
%   preModel 4: mean of the SOM and kNN predictions.
%   preModel 5: Gaussian RBF interpolation on the archive (width = median
%               pairwise distance, ridge 1e-6), the surrogate type of EGES.
%   preModel 6: topology-pooled local model (tps). Each candidate is
%               mapped to its decision-space BMU j; a local linear ridge
%               model is fitted on the archive members whose BMU lies
%               within h lattice hops of j (h grows from 1 until at least
%               8 members are pooled). The lattice is what makes a local
%               model possible with ~2 samples per node.
%   preModel 7: topology-pooled local Kriging (TP-LK, needs refMap). The
%               archive is partitioned by the map (each member belongs to
%               the region of its reference direction) and each candidate is
%               predicted by the Kriging model of the region it was
%               generated for. That model is fitted on the members of the
%               region and of its map neighbours, growing the hop radius
%               until at least 2D+1 members are pooled (at most
%               max(2D+1,40), nearest hops first). Kriging = DACE, the
%               same implementation as K-RVEA, with a constant trend,
%               Gaussian correlation, theta in [1e-5,100] warm-started per
%               region, one shared theta for the M objectives. The pooling
%               graph follows kc.poolCtrl (topology controls). For D > 30
%               the local models are not identifiable with ~100 samples
%               and the Gaussian RBF of preModel 5 is used instead.
% Selection:
%   infillD 0: lowest non-domination front of archive + predictions first,
%              ties broken by the largest predicted distance to the archive
%              and to the candidates already picked (gap filling).
%   infillD 1: decomposition. Each candidate is assigned to its nearest
%              reference direction and scored by predicted PBI (theta = 5);
%              it improves its niche if it beats the best feasible archive
%              member there (empty niches always improve). Order: predicted
%              feasible first, improving first, largest improvement first;
%              one candidate per niche in a first pass, then fill. With
%              kc.lcb = kappa > 0 and a model with uncertainty, the PBI is
%              computed on the optimistic prediction mean - kappa*sd.

    M     = Problem.M;
    Lower = Problem.lower(:)';
    Range = max(Problem.upper(:)' - Lower,eps);
    nC    = size(Cand,1);
    nArc  = length(Archive);

    ArcX = (Archive.decs - Lower)./Range;
    CanX = (Cand - Lower)./Range;
    ArcF = (Archive.objs - ideal)./(nadir - ideal + 1e-12);
    ArcC = Archive.cons;

    k = 3;
    if isfield(kc,'knnK'), k = kc.knnK; end
    k = min(k,nArc);
    [Da,Ia] = pdist2(ArcX,CanX,'euclidean','Smallest',k);
    Wa = 1./(Da + 1e-12); Wa = Wa./sum(Wa,1);

    if preModel == 3
        if M <= 3, preModel = 2; else, preModel = 1; end
    end
    if preModel == 1 || preModel == 4
        kS = min(3,size(W,1));
        [Ds,Is] = pdist2(W(:,M+1:end),CanX,'euclidean','Smallest',kS);
        Ws = 1./(Ds + 1e-12); Ws = Ws./sum(Ws,1);
        SomY = W(:,1:M);
        PredS = zeros(nC,M);
        for c = 1:nC
            PredS(c,:) = Ws(:,c)'*SomY(Is(:,c),:);
        end
    end
    if preModel == 2 || preModel == 4 || preModel == 6 || preModel == 7
        PredK = zeros(nC,M);
        for c = 1:nC
            PredK(c,:) = Wa(:,c)'*ArcF(Ia(:,c),:);
        end
    end
    PredSD = zeros(nC,M);
    switch preModel
        case 1, PredF = PredS;
        case 2, PredF = PredK;
        case 4, PredF = (PredS + PredK)/2;
        case 5
            PredF = RbfPredict(ArcX,ArcF,CanX);
        case 7
            D = size(ArcX,2);
            if D > 30 || ~isfield(kc,'LDisPool')
                PredF = RbfPredict(ArcX,ArcF,CanX);
            else
                PredF  = PredK;                               % fallback per region
                ArcDir = ArcF./max(vecnorm(ArcF,2,2),1e-12);
                [~,assocArc] = max(ArcDir*RefN',[],2);
                SomX = W(:,M+1:end);
                cn   = kc.candNode(:);
                miss = cn == 0;
                if any(miss)
                    [~,cn(miss)] = min(pdist2(CanX(miss,:),SomX),[],2);
                end
                nMin = 2*D + 1;
                nMax = max(nMin,40);
                if kc.poolCtrl == 4
                    try
                        [mu,sd,th] = LocalKriging(ArcX,ArcF,CanX,kc.thetaGlob);
                        PredF = mu; PredSD = sd; kc.thetaGlob = th;
                    catch
                    end
                else
                    for j = unique(cn)'
                        c = find(cn == j);
                        switch kc.poolCtrl
                            case {0,1}
                                idx = PoolMembers(kc.LDisPool(j,assocArc),ArcX,SomX(j,:),nMin,nMax);
                            case 2
                                idx0 = PoolMembers(kc.LDisTrue(j,assocArc),ArcX,SomX(j,:),nMin,nMax);
                                idx  = randperm(nArc,numel(idx0));
                            otherwise
                                idx = find(assocArc == j)';
                        end
                        if numel(idx) < 3, continue; end
                        try
                            [mu,sd,th] = LocalKriging(ArcX(idx,:),ArcF(idx,:),CanX(c,:),kc.thetaNode(j,:));
                            PredF(c,:) = mu; PredSD(c,:) = sd; kc.thetaNode(j,:) = th;
                        catch
                        end
                    end
                end
            end
        case 6
            PredF = PredK;                                    % fallback
            SomX  = W(:,M+1:end);
            [~,bA] = min(pdist2(ArcX,SomX),[],2);
            [~,bC] = min(pdist2(CanX,SomX),[],2);
            for j = unique(bC)'
                hop = LDis(j,bA);
                idx = [];
                for h = 1:4
                    idx = find(hop <= h);
                    if numel(idx) >= 8, break; end
                end
                if numel(idx) < 3, continue; end
                Xp = ArcX(idx,:); Yp = ArcF(idx,:);
                mx = mean(Xp,1);  my = mean(Yp,1);
                Xc = Xp - mx;     Yc = Yp - my;
                alpha = (Xc*Xc' + 1e-2*numel(idx)*eye(numel(idx))) \ Yc;
                c = find(bC == j);
                PredF(c,:) = my + (CanX(c,:) - mx)*Xc'*alpha;
            end
        otherwise, PredF = PredK;
    end
    PredC = zeros(nC,size(ArcC,2));
    for c = 1:nC
        PredC(c,:) = Wa(:,c)'*ArcC(Ia(:,c),:);
    end

    avail = true(1,nC);
    avail(Da(1,:) < 1e-6) = false;          % duplicates of archive members
    if sum(avail) < B
        avail = true(1,nC);
    end

    if infillD && ~isempty(RefN)
        theta = 5;
        if isfield(kc,'pbiTheta'), theta = kc.pbiTheta; end
        pCV   = sum(max(PredC,0),2);
        aCV   = sum(max(ArcC,0),2);
        PredDir = PredF./max(vecnorm(PredF,2,2),1e-12);
        [~,nichC] = max(PredDir*RefN',[],2);
        PredUse = PredF;                                 % LCB: optimistic prediction
        if isfield(kc,'lcb') && kc.lcb > 0 && any(PredSD(:) > 0)
            PredUse = PredF - kc.lcb*PredSD;
        end
        d1 = sum(PredUse.*RefN(nichC,:),2);
        pbiC = d1 + theta*sqrt(max(sum(PredUse.^2,2) - d1.^2,0));
        ArcDir = ArcF./max(vecnorm(ArcF,2,2),1e-12);
        [~,nichA] = max(ArcDir*RefN',[],2);
        a1 = sum(ArcF.*RefN(nichA,:),2);
        pbiA = a1 + theta*sqrt(max(sum(ArcF.^2,2) - a1.^2,0));
        bestA = inf(size(RefN,1),1);
        for i = find(aCV <= 0)'
            bestA(nichA(i)) = min(bestA(nichA(i)),pbiA(i));
        end
        gain = bestA(nichC) - pbiC;
        gain(~isfinite(bestA(nichC))) = 1e6 - pbiC(~isfinite(bestA(nichC)));
        improve = gain > 0;
        [~,order] = sortrows([double(pCV > 0), pCV, double(~improve), -gain]);
        order  = order(avail(order));
        chosen = zeros(1,0);
        taken  = false(size(RefN,1),1);
        for c = order'                                  % first pass: one per niche
            if numel(chosen) >= B, break; end
            if ~taken(nichC(c))
                chosen(end+1) = c; %#ok<AGROW>
                taken(nichC(c)) = true;
            end
        end
        for c = order'                                  % second pass: fill
            if numel(chosen) >= B, break; end
            if ~ismember(c,chosen)
                chosen(end+1) = c; %#ok<AGROW>
            end
        end
    else
        FrontNo = NDSort([ArcF;PredF],[ArcC;PredC],inf);
        cf = FrontNo(nArc+1:end);
        ref    = ArcF;
        chosen = zeros(1,0);
        for b = 1:min(B,nC)
            idxs = find(avail);
            if isempty(idxs), break; end
            best = idxs(cf(idxs) == min(cf(idxs)));
            dmin = min(pdist2(PredF(best,:),ref),[],2);
            [~,p] = max(dmin);
            pick  = best(p);
            chosen(end+1) = pick; %#ok<AGROW>
            avail(pick)   = false;
            ref = [ref; PredF(pick,:)]; %#ok<AGROW>
        end
    end
    if numel(chosen) < B
        rest = setdiff(1:nC,chosen);
        chosen = [chosen, rest(1:B-numel(chosen))];
    end
    if isfield(kc,'instr') && kc.instr && infillD && ~isempty(RefN)
        % Accuracy of the prescreening on all candidates. CalObj/CalCon spend
        % no evaluation and draw no random number, so the run is unchanged.
        TF   = (Problem.CalObj(Cand) - ideal)./(nadir - ideal + 1e-12);
        TCV  = sum(max(Problem.CalCon(Cand),0),2);
        [~,nichT] = max((TF./max(vecnorm(TF,2,2),1e-12))*RefN',[],2);
        t1   = sum(TF.*RefN(nichT,:),2);
        pbiT = t1 + theta*sqrt(max(sum(TF.^2,2) - t1.^2,0));
        gainT = bestA(nichT) - pbiT;
        gainT(~isfinite(bestA(nichT))) = 1e6 - pbiT(~isfinite(bestA(nichT)));
        impT  = gainT > 0 & TCV <= 0;
        [~,orderT] = sortrows([double(TCV > 0), TCV, double(~impT), -gainT]);
        nB = min(B,nC);
        kc.instrRow = [corr(pbiC,pbiT,'Type','Spearman'), ...        % rank agreement of predicted and true PBI
                       numel(intersect(chosen(1:nB),orderT(1:nB)))/nB, ... % precision against the true top B
                       mean(impT(chosen(1:nB))), mean(impT), ...      % truly improving: selected vs all candidates
                       nB/nC];                                         % precision of a random selection (1/K)
    end
    PredSel = PredF(chosen,:);
    SdSel   = PredSD(chosen,:);
end

function PredF = RbfPredict(ArcX,ArcF,CanX)
% Gaussian RBF interpolation on the archive (width = median pairwise
% distance, ridge 1e-6), the surrogate type of EGES.
    nArc = size(ArcX,1);
    Dm = pdist2(ArcX,ArcX);
    s  = median(Dm(Dm > 0));
    if isempty(s) || ~isfinite(s) || s <= 0, s = 1; end
    my = mean(ArcF,1);
    alpha = (exp(-(Dm/s).^2) + 1e-6*eye(nArc)) \ (ArcF - my);
    PredF = my + exp(-(pdist2(CanX,ArcX)/s).^2)*alpha;
end

function idx = PoolMembers(hopRow,ArcX,protoX,nMin,nMax)
% Archive members of a map region and of its map neighbours: the hop radius
% grows from 0 (the region itself) until at least nMin members are pooled;
% beyond nMax, the nearest hops are kept, ties broken by the decision-space
% distance to the region's prototype.
    hmax = max(hopRow(isfinite(hopRow)));
    idx  = [];
    for h = 0:hmax
        idx = find(hopRow <= h);
        if numel(idx) >= nMin, break; end
    end
    if numel(idx) > nMax
        d = sqrt(sum((ArcX(idx,:) - protoX).^2,2));
        [~,o] = sortrows([hopRow(idx)', d]);
        idx = idx(o(1:nMax));
    end
end

function [mu,sd,theta] = LocalKriging(Xtr,Ytr,Xte,theta0)
% Ordinary Kriging with DACE (the implementation used by K-RVEA): constant
% trend, Gaussian correlation, theta in [1e-5,100] warm-started at theta0,
% one shared theta for the M outputs. Duplicate sites are removed.
    D = size(Xtr,2);
    [~,ia] = unique(round(Xtr*1e12)/1e12,'rows','stable');
    Xtr = Xtr(ia,:); Ytr = Ytr(ia,:);
    theta0 = min(max(theta0,1e-5),100);
    dmodel = dacefit(Xtr,Ytr,'regpoly0','corrgauss',theta0,1e-5*ones(1,D),100*ones(1,D));
    if size(Xte,1) == 1
        [mu,~,mse] = predictor(Xte,dmodel);
        mu = mu(:)'; mse = mse(:)';
    else
        [mu,mse] = predictor(Xte,dmodel);
    end
    sd    = sqrt(max(mse,0));
    theta = dmodel.theta(:)';
end

%% =================== ENVIRONMENTAL SELECTION ===================

function Archive = TruncationSelection(Archive,K)
% NDSort up to K solutions; the last front is reduced with SPEA2-style
% truncation in normalized objective space: repeatedly drop the member of
% the last front whose distances to its 3 nearest retained neighbours are
% lexicographically smallest (3-NN tie-breaking keeps it fast for large N).

    [FrontNo,MaxFNo] = NDSort(Archive.objs,Archive.cons,K);
    Next  = FrontNo < MaxFNo;
    Last  = find(FrontNo == MaxFNo);
    slots = K - sum(Next);

    if slots >= numel(Last)
        Next(Last) = true;
    elseif slots > 0
        Obj = Archive.objs;
        Obj = (Obj - min(Obj,[],1))./(max(Obj,[],1) - min(Obj,[],1) + 1e-12);
        pool   = [find(Next), Last];
        isLast = [false(1,sum(Next)), true(1,numel(Last))];
        Dis = pdist2(Obj(pool,:),Obj(pool,:));
        Dis(logical(eye(numel(pool)))) = inf;
        LastPos   = find(isLast);
        aliveLast = true(1,numel(LastPos));
        k = max(1,min(3,numel(pool)-1));
        for r = 1:(numel(LastPos) - slots)
            cand  = LastPos(aliveLast);
            sd    = mink(Dis(cand,:),k,2);
            [~,o] = sortrows(sd);
            del   = cand(o(1));
            Dis(del,:) = inf;
            Dis(:,del) = inf;
            aliveLast(LastPos == del) = false;
        end
        Next(pool(LastPos(aliveLast))) = true;
    end
    Archive = Archive(Next);
end

function Archive = RefNicheSelection(Archive,K,RefN)
% NDSort up to K solutions; the last front is completed by
% reference-direction niching (NSGA-III style, deterministic): repeatedly
% take the least crowded niche that still has candidates in the last front
% and add its candidate with the smallest perpendicular distance.

    [FrontNo,MaxFNo] = NDSort(Archive.objs,Archive.cons,K);
    Next  = FrontNo < MaxFNo;
    Last  = find(FrontNo == MaxFNo);
    slots = K - sum(Next);

    if slots >= numel(Last)
        Next(Last) = true;
    elseif slots > 0
        pool = [find(Next), Last];
        Obj  = Archive(pool).objs;
        Obj  = (Obj - min(Obj,[],1))./(max(Obj,[],1) - min(Obj,[],1) + 1e-12);
        Dir  = Obj./max(vecnorm(Obj,2,2),1e-12);
        [~,nich] = max(Dir*RefN',[],2);
        d1   = sum(Obj.*RefN(nich,:),2);
        dperp = sqrt(max(sum(Obj.^2,2) - d1.^2,0));
        nNext = sum(Next);
        rho   = zeros(size(RefN,1),1);
        if nNext > 0
            rho = accumarray(nich(1:nNext),1,[size(RefN,1) 1]);
        end
        lastNich = nich(nNext+1:end);
        lastD    = dperp(nNext+1:end);
        picked   = false(numel(Last),1);
        for s = 1:slots
            availN = unique(lastNich(~picked));
            [~,q]  = min(rho(availN));
            jmin   = availN(q);
            cand   = find(~picked & lastNich == jmin);
            [~,b]  = min(lastD(cand));
            picked(cand(b)) = true;
            rho(jmin) = rho(jmin) + 1;
        end
        Next(Last(picked)) = true;
    end
    Archive = Archive(Next);
end
