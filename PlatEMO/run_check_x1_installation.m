function report = run_check_x1_installation(requireRuntime)
%RUN_CHECK_X1_INSTALLATION Static source/manifest checks of phase AC (version 3); zero evaluations.
% Safe on the main PC. Does not instantiate PROBLEM/ALGORITHM or create pools.
% Pass true to require a complete installed overlay (execution machine).
    if nargin < 1, requireRuntime = false; end
    blocks = {'AC1','AC2','AC3','AC4','AC5','AD1','AD2','AD3','AD4'}; perRun = [216,144,120,105,70,216,144,120,105];
    allTasks = [];
    for b = 1:numel(blocks)
        t = ac_build_tasks(blocks{b},[],1);
        assert(numel(t) == perRun(b),'AC:Grid','%s: %d tasks per run, expected %d.',blocks{b},numel(t),perRun(b));
        allTasks = [allTasks,t]; %#ok<AGROW>
    end
    for i = 1:numel(allTasks)
        t = allTasks(i);
        assert(t.param{29} == 0 && numel(t.param) == 45,'AC:Budget','Instrument flag must be zero.');
        assert(t.param{27} == strcmp(t.protocol,'popN'),'AC:Population','outN/protocol mismatch.');
        assert(strcmp(t.algName,'TPIMMOEA_X'),'AC:Algorithm','Unexpected algorithm.');
        expectedSeed = mod(sum(double(t.seedName).*(1:numel(t.seedName))) + 7919*t.run,2^31-1);
        assert(expectedSeed == t.seed,'AC:Seed','Seed mismatch.');
        o = t.param{45};
        if ~isempty(o) && ~strcmp(o.repairMode,'none')
            assert(strcmp(o.repairTrigger,'infeasible'),'AC:Repair','Repair must use the trigger ''infeasible''.');
        end
        assert(~isempty(o) && o.orderGate && strcmp(o.moveMode,'none') && strcmp(o.graphMode,'legacy'), ...
            'AC:Profile','Version 3 profiles: ordering gate on, legacy graph, no movement.');
    end
    % Historical file names (hence seeds) of g15 in C1, C2, D2 and C5 are kept exactly.
    original = [names(c_build_tasks('C1')),names(c_build_tasks('C2')),names(d_build_tasks('D2')),names(c_build_tasks('C5'))];
    fresh = arrayfun(@(b)ac_build_tasks(b{1},{'coop3'},1),blocks,'UniformOutput',false);
    fresh = unique(cellfun(@(t){t.seedName},num2cell([fresh{:}])));
    assert(numel(original) == 155 && isequal(sort(original),sort(fresh)),'AC:Seed', ...
        'Phase AC names differ from the historical g15 names.');
    source = ac_provenance(allTasks,requireRuntime);
    [h,id] = ac_task_identity(allTasks(1),source.digest);
    modified = allTasks(1); modified.param{31} = modified.param{31}+0.01;
    assert(~strcmp(h,ac_task_identity(modified,source.digest)),'AC:Hash','Parameter mutation did not alter identity.');
    report = struct('passed',true,'zeroEvaluations',true,'tasksPerRun',perRun, ...
        'source',source,'exampleIdentity',id,'exampleHash',h);
    fprintf('AC static checks passed: AC1-AC5 and AD1-AD4 grids (%s per run), 45 parameters, budget flag, gates, seed parity and task hashes. ZERO evaluations.\n', ...
        mat2str(perRun));
    if ~source.ready, fprintf('Full runtime not installed on path: %s\n',strjoin(source.missing,', ')); end
end

function n = names(tasks)
    tasks = tasks(strcmp({tasks.config},'g15') & [tasks.run] == 1);
    n = cell(1,numel(tasks));
    for i = 1:numel(tasks), [~,n{i}] = fileparts(tasks(i).outFile); end
end
