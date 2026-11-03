function run_smoke_test_v()
%RUN_SMOKE_TEST_V  Installation check of phase V (about 3 min). Every line
%must end in OK:
%   - TPIMMOEA_X with the phase V switches installed;
%   - the task list of V1: 8,100 tasks, 5 configurations, the directions of
%     each configuration and instr = 1 in every task;
%   - one run of every configuration on WFG4 with (m,d) = (3,10) and (9,100),
%     run 1: no error, the budget of 300 evaluations used, a finite IGD, a
%     map with the expected number of nodes (45 with the Das-Dennis
%     directions, 50 with the weights of MOEA/D-UR), and an IGD equal to that
%     of g15 on the same seed for V0_DasDennis and different from it for the
%     other variants.
%That g15 itself is unchanged is checked separately by run_check_tpimmoea.
%Writes only to Data_V/_smoke/, deleted at the end.

    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    smoke = fullfile(PlatEMORoot,'Data_V','_smoke');
    nFail = 0;

    src = fileread(fullfile(PlatEMORoot,'Algorithms','Multi-objective optimization','TPIMMOEA_X','TPIMMOEA_X.m'));
    nFail = nFail + report('TPIMMOEA_X with the phase V switches installed', ...
        contains(src,'refGen') && contains(src,'RandomUniformDirections') && contains(src,'baseMode'));

    T   = v_build_tasks('V1');
    cfg = unique({T.config},'stable');
    nFail = nFail + report(sprintf('V1 task count %d (expected 8100)',numel(T)),numel(T) == 8100);
    nFail = nFail + report(sprintf('V1 configurations %d (expected 5)',numel(cfg)),numel(cfg) == 5);
    nFail = nFail + report('V1 distinct output files',numel(unique({T.outFile})) == numel(T));
    nFail = nFail + report('instr = 1 in every task',all(cellfun(@(p)isequal(p{29},1),{T.param})));
    expect = {'V0_DasDennis',0,0; 'V1_URmap',1,1; 'V2_URall',1,0; 'V3_URDmap',2,1; 'V4_URDall',2,0};
    okCfg  = true;
    for v = 1 : size(expect,1)
        P = {T(strcmp({T.config},expect{v,1})).param};
        okCfg = okCfg && numel(P) == 1620 && ...
                all(cellfun(@(p)isequal(p{37},expect{v,2}) && isequal(p{38},expect{v,3}),P));
    end
    nFail = nFail + report('refGen and refScope of every configuration',okCfg);

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
        for md = [3 10; 9 100]'
            t = T(strcmp({T.config},cfg{c}) & strcmp({T.probName},'WFG4') & [T.M] == md(1) & [T.D] == md(2) & [T.run] == 1);
            [~,name] = fileparts(t.outFile);
            t.outFile = fullfile(smoke,cfg{c},[name '.mat']);
            [s,e,n] = run_one_g_task(t);
            if ~strcmp(s,'OK')
                nFail = nFail + 1;
                fprintf('%-13s m=%d FAILED: %s %s\n',cfg{c},md(1),s,n);
                continue;
            end
            S  = load(t.outFile);
            g  = ref(sprintf('%d_%d',md));
            isRef = strcmp(cfg{c},'V0_DasDennis');
            if isRef
                same = S.metric.IGDall == g;
                nExp = 45;                              % Das-Dennis with N = 50, m = 3 and m = 9
            else
                same = abs(S.metric.IGDall - g) <= 1e-12;
                nExp = 50;
            end
            nNode = size(S.metric.refN,1);
            ok = S.cfg.nRecorded == 300 && isfinite(S.metric.IGDall) && nNode == nExp && same == isRef;
            fprintf('%-13s m=%d IGDall=%.6g (g15 %.6g), %d nodes, %.1fs',cfg{c},md(1),S.metric.IGDall,g,nNode,e);
            nFail = nFail + report('',ok);
        end
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
    if isempty(label)
        fprintf('  %s\n',s);
    else
        fprintf('%-60s %s\n',label,s);
    end
    f = double(~ok);
end
