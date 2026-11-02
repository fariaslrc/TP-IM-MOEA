function run_smoke_test_u()
%RUN_SMOKE_TEST_U  Installation check of phase U (about 2 min). Every line
%must end in OK:
%   - TPIMMOEA_X with the phase U switch installed;
%   - the task list of U1: 6,480 tasks, 4 configurations, the base point and
%     the topology of each configuration, and instr = 1 in every task;
%   - one run of every configuration on WFG4 with (m,d) = (3,10) and (9,100),
%     run 1: no error, the budget of 300 evaluations used, a finite IGD, the
%     log of the base points recorded (11 columns, at least one member in
%     the parent's region), and an IGD equal to that of g15 on the same seed
%     for U0_Prototype (instrumentation draws no random number) and
%     different from it for the other variants.
%That g15 itself is unchanged is checked separately by run_check_tpimmoea.
%Writes only to Data_U/_smoke/, deleted at the end.

    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    smoke = fullfile(PlatEMORoot,'Data_U','_smoke');
    nFail = 0;

    src = fileread(fullfile(PlatEMORoot,'Algorithms','Multi-objective optimization','TPIMMOEA_X','TPIMMOEA_X.m'));
    nFail = nFail + report('TPIMMOEA_X with the phase U switch installed', ...
        contains(src,'baseMode') && contains(src,'protoLog'));

    T   = u_build_tasks('U1');
    cfg = unique({T.config},'stable');
    nFail = nFail + report(sprintf('U1 task count %d (expected 6480)',numel(T)),numel(T) == 6480);
    nFail = nFail + report(sprintf('U1 configurations %d (expected 4)',numel(cfg)),numel(cfg) == 4);
    nFail = nFail + report('U1 distinct output files',numel(unique({T.outFile})) == numel(T));
    nFail = nFail + report('instr = 1 in every task',all(cellfun(@(p)isequal(p{29},1),{T.param})));
    expect = {'U0_Prototype',0,2; 'U1_RegionMean',1,2; 'U2_RegionMember',2,2; 'U3_Parent',0,4};
    okCfg  = true;
    for v = 1 : size(expect,1)
        P = {T(strcmp({T.config},expect{v,1})).param};
        okCfg = okCfg && numel(P) == 1620 && ...
                all(cellfun(@(p)isequal(p{36},expect{v,2}) && isequal(p{14},expect{v,3}),P));
    end
    nFail = nFail + report('baseMode and topo of every configuration',okCfg);

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
                fprintf('%-16s m=%d FAILED: %s %s\n',cfg{c},md(1),s,n);
                continue;
            end
            S  = load(t.outFile);
            g  = ref(sprintf('%d_%d',md));
            if strcmp(cfg{c},'U0_Prototype')
                same = S.metric.IGDall == g;
            else
                same = abs(S.metric.IGDall - g) <= 1e-12;
            end
            okLog = isfield(S.metric,'protoLog') && size(S.metric.protoLog,2) == 11 && ...
                    all(S.metric.protoLog(:,2) >= 1);
            ok = S.cfg.nRecorded == 300 && isfinite(S.metric.IGDall) && okLog && ...
                 same == strcmp(cfg{c},'U0_Prototype');
            fprintf('%-16s m=%d IGDall=%.6g (g15 %.6g, %.1fs)',cfg{c},md(1),S.metric.IGDall,g,e);
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
