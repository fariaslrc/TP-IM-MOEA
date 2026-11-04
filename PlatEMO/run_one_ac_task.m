function [status,elapsed,note] = run_one_ac_task(t,source)
%RUN_ONE_AC_TASK Strict budgeted run; errors never become scientific results.
% Intended caller is run_ac. Direct invocation also enforces the CASA guard.
    status = 'ERROR'; note = ''; t0 = tic; tempFile = '';
    try
        host = ac_check_host();
        if nargin < 2, source = ac_provenance(t,true); end
        ac_verify_provenance(source);
        [taskHash,identity] = ac_task_identity(t,source.digest);
        if exist(t.outFile,'file') == 2
            [matches,reason] = ac_result_matches(t.outFile,t,source.digest);
            assert(matches,'AC:IncompatibleResume','Refusing to replace %s: %s.',t.outFile,reason);
            status = 'SKIP'; elapsed = toc(t0); note = 'exact completed identity'; return;
        end
        assert(t.param{29} == 0,'AC:Budget','Diagnostic objective calls must remain disabled.');
        rng(t.seed,'twister');
        ProFcn = str2func(t.probName); AlgFcn = str2func(t.algName);
        Problem = ProFcn('N',t.N,'M',t.M,'D',t.D,'maxFE',t.maxFE);
        assert(isprop(Problem,'capFE') && isprop(Problem,'recCons'),'AC:Overlay','Recording overlay is required.');
        Problem.capFE = true;
        Algorithm = AlgFcn('parameter',t.param,'save',t.saveNum,'run',t.run, ...
            'metName',{'runtime'},'outputFcn',@(varargin)[]);
        ts = tic;
        Algorithm.Solve(Problem);
        tSolve = toc(ts);
        nRecorded = size(Problem.recObjs,1);
        assert(nRecorded == t.maxFE && Problem.FE == t.maxFE && size(Problem.recCons,1) == nRecorded, ...
            'AC:Budget','Expected exactly FE=%d; FE=%d, objective records=%d, constraint records=%d.', ...
            t.maxFE,Problem.FE,nRecorded,size(Problem.recCons,1));
        assert(~isempty(Algorithm.result),'AC:Population','Missing reported population.');
        finalPopulation = Algorithm.result{end,2};
        finalObjs = finalPopulation.objs; finalCons = finalPopulation.cons; %#ok<NASGU>
        expected = 2*t.N;
        if strcmp(t.protocol,'popN'), expected = t.N; end
        assert(Problem.N == t.N && numel(finalPopulation) == expected, ...
            'AC:Population','Expected Problem.N=%d and reported size=%d; observed %d and %d.', ...
            t.N,expected,Problem.N,numel(finalPopulation));
        % WFG2 and WFG3 need an even number of distance variables, so PlatEMO raises D by one
        % when D - (M-1) is odd (e.g. M = 6, D = 10 -> 11), as in every run of the article. The
        % actual D is recorded in cfg.Dactual; only a change of M, or of D by more than one, is an error.
        assert(Problem.M == t.M && ismember(Problem.D - t.D,[0 1]),'AC:Dimensions', ...
            'Problem changed dimensions: requested M=%d,D=%d; actual M=%d,D=%d.',t.M,t.D,Problem.M,Problem.D);
        % WFG/DTLZ objectives are always finite; a real-world problem (RWMOP) may return a
        % nonfinite value at some infeasible point, which is recorded instead of stopping the campaign.
        nNonfinite = sum(~all(isfinite(Problem.recObjs),2));
        assert(~strcmp(t.protocol,'all') || (nNonfinite == 0 && all(isfinite(finalObjs(:)))), ...
            'AC:Nonfinite','Nonfinite objective encountered.');
        feasible = all(isfinite(Problem.recCons) & Problem.recCons <= 0,2);
        finalFeasible = all(isfinite(finalCons) & finalCons <= 0,2);
        first = find(feasible,1);
        if isempty(first), first = NaN; end
        cv = sum(max(0,Problem.recCons),2); cv(~all(isfinite(Problem.recCons),2)) = Inf;
        cvFinal = sum(max(0,finalCons),2); cvFinal(~all(isfinite(finalCons),2)) = Inf;
        metric = struct('runtime',toc(t0),'tSolve',tSolve,'IGDall',NaN,'IGDplusAll',NaN, ...
            'IGDreported',NaN,'HVreported',NaN,'firstFeasibleFE',first, ...
            'everFeasible',any(feasible),'finalFeasible',any(finalFeasible), ...
            'nFinalFeasible',sum(finalFeasible),'minFinalCV',min(cvFinal), ...
            'minEvaluatedCV',min(cv),'nFeasibleEvaluations',sum(feasible),'nNonfiniteEvaluations',nNonfinite);
        if strcmp(t.protocol,'all')
            F = Problem.recObjs(feasible,:);
            assert(~isempty(F),'AC:Feasibility','No feasible evaluated solutions in an unconstrained suite.');
            F = F(NDSort(F,1) == 1,:);
            [metric.IGDall,metric.IGDplusAll] = referenceDistances(F,Problem.optimum);
            if any(finalFeasible)
                metric.IGDreported = referenceDistances(finalObjs(finalFeasible,:),Problem.optimum);
            end
            assert(isfinite(metric.IGDall),'AC:Metric','IGDall must be finite.');
        else
            % Descriptive PlatEMO-normalized population HV only. The primary
            % fixed-reference RWMOP HV is computed by analysis/export_ac.
            state = rng; restore = onCleanup(@()rng(state));
            rng(1,'twister');
            Algorithm.CalMetric('HV');
            if isfield(Algorithm.metric,'HV') && ~isempty(Algorithm.metric.HV)
                metric.HVreported = Algorithm.metric.HV(end);
            end
            clear restore
        end
        % Preserve precision of narrow constraints and all available X1
        % diagnostics; do not replace the algorithm's mechanistic evidence.
        retained = {'x1GraphLog','x1GateLog','x1Options'};
        for j = 1:numel(retained)
            if isfield(Algorithm.metric,retained{j})
                metric.(retained{j}) = Algorithm.metric.(retained{j});
            end
        end
        if isfield(Algorithm.metric,'x1Diagnostics')
            [metric.x1Diag,metric.x1DiagCols,metric.x1RepairReasons] = flattenDiagnostics(Algorithm.metric.x1Diagnostics);
        end
        recObjs = Problem.recObjs; recCons = Problem.recCons; %#ok<NASGU>
        if strcmp(t.protocol,'popN')
            % RWMOP runs have 20,000-80,000 evaluations: keep the objectives in single precision
            % and the constraints as the total violation of each evaluation (<= 0 iff feasible),
            % so the audit can still recount feasibility without storing every constraint.
            recObjs = single(recObjs);
            cvRec = sum(max(0,Problem.recCons),2); cvRec(~all(isfinite(Problem.recCons),2)) = Inf;
            recCons = cvRec; %#ok<NASGU>
        end
        result = Algorithm.result; %#ok<NASGU>
        cfg = struct('schemaVersion',1,'status','COMPLETE','taskHash',taskHash, ...
            'sourceDigest',source.digest,'identity',identity,'algName',t.algName, ...
            'config',t.config,'probName',t.probName,'M',t.M,'D',t.D,'Dactual',Problem.D, ...
            'N',t.N,'problemN',Problem.N,'archiveSize',numel(finalPopulation), ...
            'maxFE',t.maxFE,'FE',Problem.FE,'nRecorded',nRecorded,'run',t.run, ...
            'seed',t.seed,'seedName',t.seedName,'protocol',t.protocol,'param',{t.param}, ...
            'capCut',Problem.capCut,'crash','','host',host,'release',version('-release'), ...
            'finishedAt',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ssXXX'))); %#ok<NASGU>
        folder = fileparts(t.outFile);
        if ~exist(folder,'dir'), mkdir(folder); end
        tempFile = [tempname(folder),'.mat'];
        save(tempFile,'cfg','metric','result','recObjs','recCons','finalObjs','finalCons','source','-v7');
        assert(exist(t.outFile,'file') ~= 2,'AC:ConcurrentWriter','Result appeared during this run; refusing overwrite.');
        [moved,message] = movefile(tempFile,t.outFile);
        assert(moved,'AC:Save','Cannot commit result: %s.',message);
        tempFile = ''; status = 'OK';
    catch err
        note = sprintf('%s: %s',err.identifier,err.message);
        if ~isempty(tempFile) && exist(tempFile,'file') == 2, delete(tempFile); end
    end
    elapsed = toc(t0);
end

function [igd,igdplus] = referenceDistances(F,R)
    assert(~isempty(R) && size(R,2) == size(F,2) && all(isfinite(R(:))), ...
        'AC:Reference','Invalid IGD reference front.');
    distances = zeros(size(R,1),1); plus = distances;
    for start = 1:256:size(R,1)
        idx = start:min(start+255,size(R,1));
        distances(idx) = min(pdist2(R(idx,:),F),[],2);
        if nargout > 1
            d2 = zeros(numel(idx),size(F,1));
            for m = 1:size(F,2)
                d2 = d2 + max(0,F(:,m).' - R(idx,m)).^2;
            end
            plus(idx) = sqrt(min(d2,[],2));
        end
    end
    igd = mean(distances); igdplus = mean(plus);
end

function [X,cols,reasons] = flattenDiagnostics(D)
%Per-generation X1 diagnostics as a numeric matrix (a cell of structs is slow and large in MAT files).
    cols = {'FE','generated','evaluated','movementGenerated','movementEvaluated','movementMeanRMS', ...
        'repairAttempted','repairGenerated','repairEvaluated','repairDuplicateReverts','repairMeanRMS', ...
        'radiusMean','movementOn','repairOn'};
    X = nan(numel(D),numel(cols)); reasons = struct('reason',{{}},'count',[]);
    for g = 1:numel(D)
        for c = 1:numel(cols)
            if isfield(D{g},cols{c}) && ~isempty(D{g}.(cols{c})), X(g,c) = double(D{g}.(cols{c})); end
        end
        if isfield(D{g},'repairReasons')
            for r = 1:numel(D{g}.repairReasons)
                k = find(strcmp(reasons.reason,D{g}.repairReasons{r}),1);
                if isempty(k), reasons.reason{end+1} = D{g}.repairReasons{r}; reasons.count(end+1) = 0; k = numel(reasons.count); end
                reasons.count(k) = reasons.count(k) + D{g}.repairReasonCounts(r);
            end
        end
    end
end
