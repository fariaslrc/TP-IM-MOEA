function [status,elapsed,note] = run_one_n50_task(t)
%RUN_ONE_N50_TASK  Worker-side unit of work for the N = 50 rerun (round 4).
%Runs one (algorithm, problem, M, D, N, FE, run) task and saves it to the
%explicit path t.outFile under Data_N50/, never to PlatEMO's default Data/,
%so N = 50 results cannot mix with older N = 100 files.
%
%   The saved file holds result, metric and cfg. cfg records the requested
%   N, the N actually seen by the problem (Problem.N), the final archive
%   size and the seed, so N can be audited later by verify_n50_results.m.
%   The seed is derived deterministically from the output file name, so
%   any single run can be reproduced exactly.

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
        args    = {'save',t.saveNum,'run',t.run,'metName',t.metName,'outputFcn',@(varargin)[]};
        if ~isempty(t.param)
            args = [{'parameter',t.param},args];
        end
        Algorithm = AlgFcn(args{:});
        Algorithm.Solve(Problem);

        if isempty(Algorithm.result)
            status = 'ERROR'; note = 'no result recorded';
        else
            if Algorithm.result{end,1} < t.maxFE
                note = sprintf('terminated early at FE=%d/%d',Algorithm.result{end,1},t.maxFE);
            end
            for i = 1:numel(t.metName)
                Algorithm.CalMetric(t.metName{i});
            end
            archiveSize = numel(Algorithm.result{end,2});
            % Baselines (checkArchive = false) are only checked for the
            % requested N: decomposition-based ones round Problem.N to the
            % number of uniform weight vectors (e.g. 45 or 42 for N = 50) and
            % keep a final population whose size is not 2N. Both values are
            % still recorded in cfg (problemN, archiveSize).
            checkArc = ~isfield(t,'checkArchive') || t.checkArchive;
            if checkArc && (Problem.N ~= t.N || archiveSize ~= 2*t.N)
                status = 'NCHECK';
                note   = sprintf('Problem.N=%d archive=%d (expected N=%d, archive=%d)', ...
                                 Problem.N,archiveSize,t.N,2*t.N);
            end
            result = Algorithm.result; %#ok<NASGU>
            metric = Algorithm.metric; %#ok<NASGU>
            cfg = struct('algName',t.algName,'probName',t.probName,'M',t.M,'D',t.D, ...
                         'Dactual',Problem.D,'N',t.N,'problemN',Problem.N,'archiveSize',archiveSize, ...
                         'maxFE',t.maxFE,'run',t.run,'seed',seed,'param',{t.param}, ...
                         'config',t.config,'checkArchive',checkArc); %#ok<NASGU>
            folder = fileparts(t.outFile);
            [~,~]  = mkdir(folder);
            save(t.outFile,'result','metric','cfg');
        end
    catch err
        status = 'ERROR';
        note   = err.message;
    end
    elapsed = toc(t0);
end
