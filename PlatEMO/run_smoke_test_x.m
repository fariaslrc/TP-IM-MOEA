function run_smoke_test_x()
%RUN_SMOKE_TEST_X  Installation check of phase X (about 2 min). Every line
%must end in OK:
%   - TPIMMOEA_X with the phase X switch installed;
%   - the task list of X1: 6,480 tasks, 4 configurations, the switches of
%     each configuration and instr = 1 in every task;
%   - one run of every configuration on WFG4 with (m,d) = (3,10) and (9,100),
%     run 1: no error, the budget of 300 evaluations used, a finite IGD, the
%     Das-Dennis map of 45 nodes and the log of the cell read-out; per
%     configuration, neighbours with a positive weight in some generation
%     (the read-out is active) and an IGD different from that of g15 on the
%     same seed in at least one of the two runs.
%That g15 itself is unchanged is checked separately by run_check_tpimmoea.
%Writes only to Data_X/_smoke/, deleted at the end.

    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    smoke = fullfile(PlatEMORoot,'Data_X','_smoke');
    nFail = 0;

    src = fileread(fullfile(PlatEMORoot,'Algorithms','Multi-objective optimization','TPIMMOEA_X','TPIMMOEA_X.m'));
    nFail = nFail + report('TPIMMOEA_X with the phase X switch installed', ...
        contains(src,'cellRead') && contains(src,'updatedNow') && contains(src,'SimplexWeights'));

    T   = x_build_tasks('X1');
    cfg = unique({T.config},'stable');
    nFail = nFail + report(sprintf('X1 task count %d (expected 6480)',numel(T)),numel(T) == 6480);
    nFail = nFail + report(sprintf('X1 configurations %d (expected 4)',numel(cfg)),numel(cfg) == 4);
    nFail = nFail + report('X1 distinct output files',numel(unique({T.outFile})) == numel(T));
    nFail = nFail + report('instr = 1 in every task',all(cellfun(@(p)isequal(p{29},1),{T.param})));
    expect = {'X1_TPN',0.2,0,1; 'X2_TPN_noOrd',0,0,1; 'X3_TPN_shuf',0.2,1,1; 'X4_Prox',0,0,2};
    okCfg  = true;
    for v = 1 : size(expect,1)
        P = {T(strcmp({T.config},expect{v,1})).param};
        okCfg = okCfg && numel(P) == 1620 && ...
                all(cellfun(@(p)isequal(p{31},expect{v,2}) && isequal(p{41},expect{v,3}) && isequal(p{42},expect{v,4}),P));
    end
    nFail = nFail + report('nbPhase, graphShuf and cellRead of every configuration',okCfg);

    C1  = c_build_tasks('C1');
    ref = containers.Map();                     % IGD of g15 on the same seeds, computed here
    for md = [3 10; 9 100]'
        t = C1(strcmp({C1.config},'g15') & strcmp({C1.probName},'WFG4') & [C1.M] == md(1) & [C1.D] == md(2) & [C1.run] == 1);
        [~,name] = fileparts(t.outFile);
        t.outFile = fullfile(smoke,'g15',[name '.mat']);
        run_one_c_task(t);
        S = load(t.outFile);
        ref(sprintf('%d_%d',md)) = S.metric.IGDall;
    end

    for c = 1 : numel(cfg)
        differs = false; active = false; okRuns = true;
        for md = [3 10; 9 100]'
            t = T(strcmp({T.config},cfg{c}) & strcmp({T.probName},'WFG4') & [T.M] == md(1) & [T.D] == md(2) & [T.run] == 1);
            [~,name] = fileparts(t.outFile);
            t.outFile = fullfile(smoke,cfg{c},[name '.mat']);
            [s,e,n] = run_one_g_task(t);
            if ~strcmp(s,'OK')
                okRuns = false;
                fprintf('%-13s m=%d FAILED: %s %s\n',cfg{c},md(1),s,n);
                continue;
            end
            S = load(t.outFile);
            g = ref(sprintf('%d_%d',md));
            differs = differs || abs(S.metric.IGDall - g) > 1e-12;
            hasLog  = isfield(S.metric,'cellLog') && size(S.metric.cellLog,2) == 7;
            okRuns  = okRuns && hasLog && S.cfg.nRecorded == 300 && isfinite(S.metric.IGDall) && size(S.metric.refN,1) == 45;
            if hasLog
                active = active || any(S.metric.cellLog(:,3) > 0);
                fprintf('%-13s m=%d IGDall=%.6g (g15 %.6g), mean weight on neighbours %.3f, residual %.3g, %.1fs\n', ...
                    cfg{c},md(1),S.metric.IGDall,g,mean(S.metric.cellLog(:,3),'omitnan'),mean(S.metric.cellLog(:,2),'omitnan'),e);
            end
        end
        nFail = nFail + report(sprintf('%s: runs complete, read-out active, IGD differs',cfg{c}),okRuns && active && differs);
    end
    if exist(smoke,'dir'), rmdir(smoke,'s'); end
    if nFail == 0
        fprintf('\nAll smoke tests passed.\n');
    else
        fprintf('\n%d smoke test(s) FAILED. Do not launch the batch yet.\n',nFail);
    end
end

function f = report(label,ok)
    if ok, s = 'OK'; else, s = 'FAILED'; end
    fprintf('%-60s %s\n',label,s);
    f = double(~ok);
end
