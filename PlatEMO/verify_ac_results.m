function summary = verify_ac_results(block,profiles,runs)
%VERIFY_AC_RESULTS Read-only audit of identity, budget and result records.
    if nargin < 1 || isempty(block), block = 'AC_A'; end
    if nargin < 2, profiles = []; end
    if nargin < 3, runs = []; end
    tasks = ac_build_tasks(block,profiles,runs);
    source = ac_provenance(tasks,false);
    entries = repmat(struct('file','','profile','','problem','','run',0,'status','','reason',''),1,numel(tasks));
    for i = 1:numel(tasks)
        [ok,why] = ac_result_matches(tasks(i).outFile,tasks(i),source.digest);
        state = 'INVALID';
        if strcmp(why,'missing'), state = 'MISSING'; elseif ok, state = 'COMPLETE'; end
        if ok
            try
                s = load(tasks(i).outFile,'recObjs','recCons','metric','finalObjs','finalCons');
                assert(size(s.recObjs,1) == tasks(i).maxFE && size(s.recCons,1) == tasks(i).maxFE, ...
                    'AC:Audit','Evaluation records do not match maxFE.');
                assert(size(s.recObjs,2) == tasks(i).M && (strcmp(tasks(i).protocol,'popN') || all(isfinite(s.recObjs(:)))), ...
                    'AC:Audit','Invalid objective record dimensions/values.');
                feasible = all(isfinite(s.recCons) & s.recCons <= 0,2);
                first = find(feasible,1); if isempty(first), first = NaN; end
                assert(isequaln(first,s.metric.firstFeasibleFE) && any(feasible) == s.metric.everFeasible, ...
                    'AC:Audit','First-feasible/ever-feasible statistics disagree with records.');
                finalFeasible = all(isfinite(s.finalCons) & s.finalCons <= 0,2);
                assert(sum(finalFeasible) == s.metric.nFinalFeasible && ...
                    any(finalFeasible) == s.metric.finalFeasible,'AC:Audit','Final feasibility statistics disagree.');
            catch err
                state = 'INVALID'; why = err.message;
            end
        end
        entries(i) = struct('file',tasks(i).outFile,'profile',tasks(i).config, ...
            'problem',tasks(i).probName,'run',tasks(i).run,'status',state,'reason',why);
    end
    states = {entries.status};
    summary = struct('block',upper(char(block)),'sourceDigest',source.digest,'nExpected',numel(tasks), ...
        'nComplete',sum(strcmp(states,'COMPLETE')),'nMissing',sum(strcmp(states,'MISSING')), ...
        'nInvalid',sum(strcmp(states,'INVALID')),'entries',entries);
    fprintf('%s: %d/%d COMPLETE; %d MISSING; %d INVALID.\n',summary.block,summary.nComplete, ...
        summary.nExpected,summary.nMissing,summary.nInvalid);
end
