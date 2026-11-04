function [ok,reason] = ac_result_matches(file,t,sourceDigest)
%AC_RESULT_MATCHES Resume only complete results with exact identity.
    ok = false; reason = 'missing';
    if exist(file,'file') ~= 2, return; end
    try
        s = load(file,'cfg','metric','finalObjs','finalCons');
        if ~isfield(s,'cfg') || ~isfield(s.cfg,'taskHash')
            reason = 'missing task identity'; return;
        end
        expected = ac_task_identity(t,sourceDigest);
        if ~strcmp(s.cfg.taskHash,expected) || ~strcmp(s.cfg.sourceDigest,sourceDigest)
            reason = 'configuration/source hash mismatch'; return;
        end
        if ~strcmp(s.cfg.status,'COMPLETE') || s.cfg.nRecorded ~= t.maxFE || s.cfg.FE ~= t.maxFE
            reason = 'incomplete budget/status'; return;
        end
        variables = whos('-file',file);
        objectives = variables(strcmp({variables.name},'recObjs'));
        constraints = variables(strcmp({variables.name},'recCons'));
        provenance = variables(strcmp({variables.name},'source'));
        if numel(objectives) ~= 1 || ~isequal(objectives.size,[t.maxFE,t.M]) || ...
                numel(constraints) ~= 1 || numel(constraints.size) ~= 2 || ...
                constraints.size(1) ~= t.maxFE || numel(provenance) ~= 1
            reason = 'missing/truncated raw evaluation records or source manifest'; return;
        end
        reportN = 2*t.N;
        if strcmp(t.protocol,'popN'), reportN = t.N; end
        if s.cfg.problemN ~= t.N || s.cfg.archiveSize ~= reportN || ...
                ~isfield(s,'finalObjs') || ~isequal(size(s.finalObjs),[reportN,t.M]) || ...
                ~all(isfinite(s.finalObjs(:))) || ...
                ~isfield(s,'finalCons') || size(s.finalCons,1) ~= reportN
            reason = 'population/constraint record mismatch'; return;
        end
        if strcmp(t.protocol,'all') && (~isfield(s.metric,'IGDall') || ~isfinite(s.metric.IGDall))
            reason = 'missing/nonfinite IGDall'; return;
        end
        fields = {'firstFeasibleFE','everFeasible','finalFeasible','nFinalFeasible','minFinalCV','tSolve'};
        if ~all(isfield(s.metric,fields))
            reason = 'missing feasibility/runtime statistics'; return;
        end
        ok = true; reason = 'complete';
    catch err
        reason = ['unreadable/invalid: ',err.message];
    end
end
