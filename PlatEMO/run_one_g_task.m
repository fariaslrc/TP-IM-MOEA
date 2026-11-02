function [status,elapsed,note] = run_one_g_task(t)
%RUN_ONE_G_TASK  run_one_d_task of phase D with one addition: when the task
%has crashTolerant = true and the algorithm stops with an error, the run is
%scored on the evaluations made before the error (cfg.crash holds the
%message), which is the failure policy of the article for WFG and DTLZ.
%Same seed rule, budget cap and scoring as phases C and D; metric.tSolve
%is the wall time of Algorithm.Solve alone. The problem refuses
%every evaluation beyond maxFE and records all evaluations (PROBLEM.capFE).
%The score follows t.protocol:
%   'all'   metric.IGDall: IGD of the nondominated solutions among all
%           evaluations; their objectives are saved (recObjs, single) for
%           convergence curves
%   'popN'  metric.HV of the reported population of size N
%The metric of the reported set used in the earlier phases (metric.IGD or
%metric.HV) is also kept, so the effect of the protocol can be measured
%run by run.

    status = 'OK';
    note   = '';
    t0     = tic;
    try
        [~,name] = fileparts(t.outFile);
        seed = mod(sum(double(name).*(1:numel(name))) + 7919*t.run, 2^31-1);
        rng(seed,'twister');

        ProFcn  = str2func(t.probName);
        AlgFcn  = str2func(t.algName);
        Problem = ProFcn('N',t.N,'M',t.M,'D',t.D,'maxFE',t.maxFE);
        Problem.capFE = true;
        args    = {'save',t.saveNum,'run',t.run,'metName',t.metName,'outputFcn',@(varargin)[]};
        if ~isempty(t.param)
            args = [{'parameter',t.param},args];
        end
        Algorithm = AlgFcn(args{:});
        tS = tic;
        crash = '';
        try
            Algorithm.Solve(Problem);
        catch errSolve
            if isfield(t,'crashTolerant') && t.crashTolerant && size(Problem.recObjs,1) > 0
                crash = errSolve.message;
            else
                rethrow(errSolve);
            end
        end
        tSolve = toc(tS);
        tRun = toc(t0);

        nRec = size(Problem.recObjs,1);
        if nRec > t.maxFE
            error('budget guard failed: %d evaluations recorded',nRec);
        end
        if nRec < t.maxFE
            note = sprintf('stopped at FE=%d/%d',nRec,t.maxFE);
        end
        if ~isempty(crash)
            note = sprintf('error at FE=%d, scored on the evaluations before it: %s',nRec,crash);
        end

        % Metric of the reported set, as in the earlier phases
        archiveSize = 0;
        if ~isempty(Algorithm.result)
            for i = 1 : numel(t.metName)
                Algorithm.CalMetric(t.metName{i});
            end
            archiveSize = numel(Algorithm.result{end,2});
        end
        metric = Algorithm.metric;
        metric.runtime = tRun;      % wall time of the run (a budget cut ends it inside Evaluation)
        metric.tSolve  = tSolve;    % optimization only: the time reported in the paper

        recObjs = [];
        switch t.protocol
            case 'all'
                F  = Problem.recObjs(all(Problem.recCons <= 0,2),:);
                ND = F(NDSort(F,1) == 1,:);
                metric.IGDall = mean(min(pdist2(Problem.optimum,ND),[],2));
                recObjs = single(Problem.recObjs); %#ok<NASGU>
            case 'popN'
                if ~isfield(metric,'HV')
                    error('no reported population');
                end
        end

        % TP-IM-MOEA reports its 2N archive, or N members with outN = 1
        checkArc = ~isfield(t,'checkArchive') || t.checkArchive;
        if checkArc
            expected = 2*t.N;
            if strcmp(t.protocol,'popN'), expected = t.N; end
            if Problem.N ~= t.N || archiveSize ~= expected
                status = 'NCHECK';
                note   = sprintf('Problem.N=%d reported=%d (expected N=%d, reported=%d)', ...
                                 Problem.N,archiveSize,t.N,expected);
            end
        end
        result = Algorithm.result; %#ok<NASGU>
        cfg = struct('algName',t.algName,'probName',t.probName,'M',t.M,'D',t.D, ...
                     'Dactual',Problem.D,'N',t.N,'problemN',Problem.N,'archiveSize',archiveSize, ...
                     'maxFE',t.maxFE,'run',t.run,'seed',seed,'param',{t.param}, ...
                     'config',t.config,'checkArchive',checkArc,'protocol',t.protocol, ...
                     'nRecorded',nRec,'capCut',Problem.capCut,'crash',crash); %#ok<NASGU>
        folder = fileparts(t.outFile);
        [~,~]  = mkdir(folder);
        save(t.outFile,'result','metric','cfg','recObjs');
    catch err
        status = 'ERROR';
        note   = err.message;
    end
    elapsed = toc(t0);
end
