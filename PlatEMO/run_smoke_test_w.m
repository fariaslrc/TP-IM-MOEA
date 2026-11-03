function run_smoke_test_w()
%RUN_SMOKE_TEST_W  Installation check of phase W (about 3 min). Every line
%must end in OK:
%   - TPIMMOEA_X with the phase W switches installed;
%   - the task list of W1: 12,960 tasks, 8 configurations, the switches of
%     each configuration and instr = 1 in every task;
%   - one run of every configuration on WFG4 with (m,d) = (3,10) and (9,100),
%     run 1: no error, the budget of 300 evaluations used, a finite IGD and
%     the Das-Dennis map of 45 nodes; per configuration, an IGD different
%     from that of g15 on the same seed in at least one of the two runs
%     (otherwise the switch would have had no effect).
%That g15 itself is unchanged is checked separately by run_check_tpimmoea.
%Writes only to Data_W/_smoke/, deleted at the end.

    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    smoke = fullfile(PlatEMORoot,'Data_W','_smoke');
    nFail = 0;

    src = fileread(fullfile(PlatEMORoot,'Algorithms','Multi-objective optimization','TPIMMOEA_X','TPIMMOEA_X.m'));
    nFail = nFail + report('TPIMMOEA_X with the phase W switches installed', ...
        contains(src,'SimplexWeights') && contains(src,'GuardedMean') && contains(src,'graphShuf') && contains(src,'refGen'));

    T   = w_build_tasks('W1');
    cfg = unique({T.config},'stable');
    nFail = nFail + report(sprintf('W1 task count %d (expected 12960)',numel(T)),numel(T) == 12960);
    nFail = nFail + report(sprintf('W1 configurations %d (expected 8)',numel(cfg)),numel(cfg) == 8);
    nFail = nFail + report('W1 distinct output files',numel(unique({T.outFile})) == numel(T));
    nFail = nFail + report('instr = 1 in every task',all(cellfun(@(p)isequal(p{29},1),{T.param})));
    expect = {'W1_Fill',1,0,0; 'W1s_FillShuf',1,0,1; 'W2_Interp',0,1,0; 'W2s_InterpShuf',0,1,1; ...
              'W2p_InterpProx',0,2,0; 'W3_FillLocal',2,0,0; 'W3s_FillLocalShuf',2,0,1; 'W4_InterpFillLocal',2,1,0};
    okCfg  = true;
    for v = 1 : size(expect,1)
        P = {T(strcmp({T.config},expect{v,1})).param};
        okCfg = okCfg && numel(P) == 1620 && all(cellfun(@(p)isequal(p(39:41),expect(v,2:4)),P));
    end
    nFail = nFail + report('fill, interp and graphShuf of every configuration',okCfg);

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
        differs = false; okRuns = true;
        for md = [3 10; 9 100]'
            t = T(strcmp({T.config},cfg{c}) & strcmp({T.probName},'WFG4') & [T.M] == md(1) & [T.D] == md(2) & [T.run] == 1);
            [~,name] = fileparts(t.outFile);
            t.outFile = fullfile(smoke,cfg{c},[name '.mat']);
            [s,e,n] = run_one_g_task(t);
            if ~strcmp(s,'OK')
                okRuns = false;
                fprintf('%-19s m=%d FAILED: %s %s\n',cfg{c},md(1),s,n);
                continue;
            end
            S = load(t.outFile);
            g = ref(sprintf('%d_%d',md));
            differs = differs || abs(S.metric.IGDall - g) > 1e-12;
            okRuns  = okRuns && S.cfg.nRecorded == 300 && isfinite(S.metric.IGDall) && size(S.metric.refN,1) == 45;
            fprintf('%-19s m=%d IGDall=%.6g (g15 %.6g, %.1fs)\n',cfg{c},md(1),S.metric.IGDall,g,e);
        end
        nFail = nFail + report(sprintf('%s: runs complete, IGD differs from g15',cfg{c}),okRuns && differs);
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
