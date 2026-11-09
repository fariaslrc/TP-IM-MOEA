function run_smoke_test_ac()
%RUN_SMOKE_TEST_AC  Installation check of phase AC (version 3), execution machine only (ac_check_host), about 15 min.
%Every line must end in OK:
%   1. static checks (grids, seeds, profiles), unit tests and the synthetic integration test;
%   2. quadprog available (repair profiles);
%   3. reproduction of run 1 of the article, exactly: g15 and X1 (legacy) on WFG4 (m = 3 and 15),
%      DTLZ2 (m = 3) and RWMOP1; 'gated' equals X1 on WFG4 m = 3 and RWMOP1 (H1 >= 2) and X2 of
%      phase Y on WFG4 m = 15 (H1 = 1), so 'gated' needs no campaign runs;
%   4. non-interference: without constraints, gated_repair_som gives exactly the run of 'gated';
%   5. timing of AC4: gated and gated_repair_som on RWMOP1 and RWMOP30 (run 1), with the number of
%      generations in which the repair was on.
%Writes only to Data_AC/_smoke/, deleted at the end.

    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    ac_check_host();
    smoke = fullfile(PlatEMORoot,'Data_AC','_smoke');
    if exist(smoke,'dir'), rmdir(smoke,'s'); end
    nFail = 0;

    nFail = nFail + guarded('static checks of AC1-AC4 (run_check_x1_installation)',@()run_check_x1_installation(true));
    nFail = nFail + guarded('unit tests of the X1 helpers (run_x1_unit_tests)',@()run_x1_unit_tests());
    nFail = nFail + guarded('synthetic integration test (test_x1_integration)',@()test_x1_integration());
    nFail = nFail + report('quadprog available (Optimization Toolbox)',~isempty(which('quadprog')) && license('test','Optimization_Toolbox'));

    % Historical run 1 (metric.IGDall of the saved runs; RWMOP: sums over the final N members)
    ref = {'AC1','WFG4',3,10,'g15',0.441626967539076; 'AC1','WFG4',3,10,'legacy',0.409261289520922;
           'AC2','WFG4',15,24,'g15',12.3740525119959; 'AC2','WFG4',15,24,'legacy',17.525456651634;
           'AC3','DTLZ2',3,10,'g15',0.175080285833024; 'AC3','DTLZ2',3,10,'legacy',0.143543680325121;
           'AC4','RWMOP1',2,4,'g15',-2410407103.98338; 'AC4','RWMOP1',2,4,'legacy',-2390916963.13227;
           'AC1','WFG4',3,10,'gated',0.409261289520922; 'AC2','WFG4',15,24,'gated',12.748281802811;
           'AC4','RWMOP1',2,4,'gated',-2390916963.13227};
    for r = 1 : size(ref,1)
        [s,el] = runOne(ref{r,1},ref{r,5},ref{r,2},ref{r,3},ref{r,4},smoke);
        if isempty(s), nFail = nFail + report(sprintf('%s %s m=%d run 1 reproduces the article',ref{r,5},ref{r,2},ref{r,3}),false); continue; end
        if strcmp(ref{r,1},'AC4'), v = sum(s.finalObjs(:)); ok = abs(v - ref{r,6}) <= 1e-9*abs(ref{r,6});
        else, v = s.metric.IGDall; ok = abs(v - ref{r,6}) <= 1e-12; end
        nFail = nFail + report(sprintf('%-6s %-6s m=%-2d run 1: %.15g (expected %.15g, %.1f s)',ref{r,5},ref{r,2},ref{r,3},v,ref{r,6},el),ok);
    end

    % Non-interference of the repair without constraints
    s0 = runOne('AC1','gated','WFG4',3,10,smoke);
    s  = runOne('AC1','gated_repair_som','WFG4',3,10,smoke);
    ok = ~isempty(s0) && ~isempty(s) && isequal(s.recObjs,s0.recObjs) && ~any(s.metric.x1GateLog(:,3));
    nFail = nFail + report('gated_repair_som WFG4 m=3 identical to gated, repair never on (no constraints)',ok);

    % Timing of AC4 (RWMOP budgets of Kumar et al.)
    T4 = ac_build_tasks('AC4',{'coop3'},1);
    tm = struct();
    for prob = {'RWMOP1','RWMOP30'}
        for prof = {'gated','gated_repair_som'}
            k = find(strcmp({T4.probName},prob{1}),1);
            [s,el] = runOne('AC4',prof{1},prob{1},T4(k).M,T4(k).D,smoke);
            ok = ~isempty(s);
            g = [0 0];
            if ok && isfield(s.metric,'x1GateLog'), g = [size(s.metric.x1GateLog,1),sum(s.metric.x1GateLog(:,3))]; elseif ok, g = [NaN 0]; end
            if ok, fe = s.cfg.maxFE; feas = s.metric.finalFeasible; else, fe = NaN; feas = false; end
            tm.(prof{1}).(prob{1}) = el;
            nFail = nFail + report(sprintf('%-16s %-7s %6d FE: %6.1f s, %d generations, repair on in %d, final feasible %d', ...
                prof{1},prob{1},fe,el,g(1),g(2),feas),ok);
        end
    end
    if isfield(tm,'gated_repair_som') && isfield(tm,'gated')
        fprintf('AC4 cost factor of the repair (gated_repair_som/gated): %.1fx\n', ...
            mean([tm.gated_repair_som.RWMOP1/tm.gated.RWMOP1, tm.gated_repair_som.RWMOP30/tm.gated.RWMOP30]));
    end

    for b = {'AC1','AC2','AC3','AC4'}, run_ac(b{1}); end      % dry run: task counts only
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
    % A run repeated within the smoke test (e.g. 'gated' as reference and as timing) is run again,
    % not skipped as already complete, so that its score and its time are both measured.
    if exist(t.outFile,'file') == 2, delete(t.outFile); end
    [status,el,note] = run_one_ac_task(t);
    if ~strcmp(status,'OK'), fprintf('  %s %s: %s %s\n',profile,prob,status,note); return; end
    s = load(t.outFile);
end

function f = guarded(label,fn)
    try
        fn(); f = report(label,true);
    catch err
        fprintf('  %s\n',err.message); f = report(label,false);
    end
end

function f = report(label,ok)
    if ok, fprintf('%-100s OK\n',label); f = 0; else, fprintf('%-100s FAILED\n',label); f = 1; end
end
