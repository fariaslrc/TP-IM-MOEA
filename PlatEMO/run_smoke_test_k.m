function run_smoke_test_k()
%RUN_SMOKE_TEST_K  Installation check of phase K (about 1 min). Every line
%must end in OK: TPIMMOEA_X with topo = 4 installed, the task count of K1,
%topo = 4 in every task, and one K1 run (WFG4, m = 3, d = 10, run 1) that
%completes the budget of 300 evaluations. That g15 is unchanged is checked
%separately by run_check_tpimmoea. Writes only to Data_K/_smoke/, deleted
%at the end.

    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    smoke = fullfile(PlatEMORoot,'Data_K','_smoke');
    nFail = 0;

    src = fileread(fullfile(PlatEMORoot,'Algorithms','Multi-objective optimization','TPIMMOEA_X','TPIMMOEA_X.m'));
    nFail = nFail + report('TPIMMOEA_X with topo = 4 installed',contains(src,'topo == 2 || topo == 4'));
    T = k_build_tasks('K1');
    nFail = nFail + report(sprintf('K1 task count %d (expected 1620)',numel(T)),numel(T) == 1620);
    nFail = nFail + report('topo = 4 in every K1 task',all(cellfun(@(p)p{14} == 4,{T.param})));

    t = T(strcmp({T.probName},'WFG4') & [T.M] == 3 & [T.D] == 10 & [T.run] == 1);
    [~,name] = fileparts(t.outFile);
    t.outFile = fullfile(smoke,[name '.mat']);
    [s,e,n] = run_one_c_task(t);
    if strcmp(s,'OK')
        S = load(t.outFile);
        fprintf('K1 noSOM WFG4 m3 d10 run 1: IGDall=%.15g FE=%d (%.1fs)',S.metric.IGDall,S.cfg.nRecorded,e);
        nFail = nFail + report('',isfinite(S.metric.IGDall) && S.cfg.nRecorded == 300);
    else
        nFail = nFail + 1;
        fprintf('K1 noSOM run FAILED: %s %s\n',s,n);
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
