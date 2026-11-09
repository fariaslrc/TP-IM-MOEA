function run_smoke_test_ac5()
%RUN_SMOKE_TEST_AC5  Installation check of block AC5 (phase AC), execution machine only (ac_check_host), about 5 min.
%Every line must end in OK:
%   1. static checks (grids AC1-AC5, seeds, profiles);
%   2. reproduction, exactly, of run 1 of phase AC with this installation: gated_mass on DTLZ2
%      (m = 3) and WFG4 (m = 3), and gated_repair_global on RWMOP30 (sum over the final N members);
%   3. one run of each AC5 profile on RWMOP30 (run 1): no error, feasible final set for the profile
%      with repair, and the solve time.
%Writes only to Data_AC/_smoke/, deleted at the end.
    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    ac_check_host();
    smoke = fullfile(PlatEMORoot,'Data_AC','_smoke');
    if exist(smoke,'dir'), rmdir(smoke,'s'); end
    nFail = 0;
    try
        run_check_x1_installation(true); nFail = nFail + report('static checks of AC1-AC5 (run_check_x1_installation)',true);
    catch err
        fprintf('  %s\n',err.message); nFail = nFail + report('static checks of AC1-AC5 (run_check_x1_installation)',false);
    end

    ref = {'AC3','gated_mass','DTLZ2',3,10,0.130534480379087; 'AC1','gated_mass','WFG4',3,10,0.440880507727858;
           'AC4','gated_repair_global','RWMOP30',2,25,46.5126200057014};
    for r = 1 : size(ref,1)
        [s,el] = runOne(ref{r,1},ref{r,2},ref{r,3},ref{r,4},ref{r,5},smoke);
        if isempty(s), nFail = nFail + report(sprintf('%s %s run 1 reproduces phase AC',ref{r,2},ref{r,3}),false); continue; end
        if strcmp(ref{r,1},'AC4'), v = sum(s.finalObjs(:)); ok = abs(v - ref{r,6}) <= 1e-9*abs(ref{r,6});
        else, v = s.metric.IGDall; ok = abs(v - ref{r,6}) <= 1e-12; end
        nFail = nFail + report(sprintf('%-20s %-8s m=%d run 1: %.15g (expected %.15g, %.1f s)',ref{r,2},ref{r,3},ref{r,4},v,ref{r,6},el),ok);
    end

    for prof = {'gated_mass','gated_mass_repair_global'}
        [s,el] = runOne('AC5',prof{1},'RWMOP30',2,25,smoke);
        ok = ~isempty(s) && (~contains(prof{1},'repair') || s.metric.finalFeasible);
        feas = ~isempty(s) && s.metric.finalFeasible;
        nFail = nFail + report(sprintf('%-24s RWMOP30 run 1: %.1f s, final feasible %d',prof{1},el,feas),ok);
    end

    run_ac('AC5');                                            % dry run: 2100 tasks
    if exist(smoke,'dir'), rmdir(smoke,'s'); end
    if nFail == 0, fprintf('\nAll smoke tests passed.\n'); else, fprintf('\n%d smoke test(s) FAILED.\n',nFail); end
end

function [s,el] = runOne(block,profile,prob,M,D,smoke)
    s = []; el = NaN;
    T = ac_build_tasks(block,{profile},1);
    k = find(strcmp({T.probName},prob) & [T.M] == M & [T.D] == D,1);
    if isempty(k), fprintf('  no task %s %s M=%d D=%d\n',block,prob,M,D); return; end
    t = T(k);
    [~,name] = fileparts(t.outFile);
    t.outFile = fullfile(smoke,profile,[name '.mat']);
    if exist(t.outFile,'file') == 2, delete(t.outFile); end
    [status,el,note] = run_one_ac_task(t);
    if ~strcmp(status,'OK'), fprintf('  %s %s: %s %s\n',profile,prob,status,note); return; end
    s = load(t.outFile);
end

function f = report(label,ok)
    if ok, fprintf('%-100s OK\n',label); f = 0; else, fprintf('%-100s FAILED\n',label); f = 1; end
end
