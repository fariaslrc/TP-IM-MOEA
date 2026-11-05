function run_smoke_test_ad()
%RUN_SMOKE_TEST_AD  Installation check of phase AD (proposals A and B on the final model F),
%CASA only, about 10 min. Every line must end in OK:
%   1. static checks (grids AC1-AC5 and AD1-AD4, seeds, profiles);
%   2. the new code leaves F unchanged: F (gated_repair_global) reproduces run 1 of X1 on WFG4
%      (m = 3), of X2 on WFG4 (m = 15) and of block AC4 on RWMOP30, exactly;
%   3. every AD profile runs on DTLZ7 (m = 3 and 6, d = 10), WFG4 (m = 3) and RWMOP30 (run 1):
%      no error and a finite score; the mean number of unreachable niches (A) and of cut edges (B)
%      per generation is printed; final_Brand (random cuts, same count as the test of B in each
%      generation) differs from final_B whenever edges are cut.
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
        run_check_x1_installation(true); nFail = nFail + report('static checks of AC1-AC5 and AD1-AD4',true);
    catch err
        fprintf('  %s\n',err.message); nFail = nFail + report('static checks of AC1-AC5 and AD1-AD4',false);
    end

    ref = {'AC1','WFG4',3,10,0.409261289520922; 'AC2','WFG4',15,24,12.748281802811; 'AC4','RWMOP30',2,25,46.5126200057014};
    for r = 1 : size(ref,1)
        [s,el] = runOne(ref{r,1},'gated_repair_global',ref{r,2},ref{r,3},ref{r,4},smoke);
        if isempty(s), nFail = nFail + report(sprintf('F %s m=%d run 1 unchanged',ref{r,2},ref{r,3}),false); continue; end
        if strcmp(ref{r,1},'AC4'), v = sum(s.finalObjs(:)); ok = abs(v - ref{r,5}) <= 1e-9*abs(ref{r,5});
        else, v = s.metric.IGDall; ok = abs(v - ref{r,5}) <= 1e-12; end
        nFail = nFail + report(sprintf('F unchanged: %-8s m=%-2d run 1: %.15g (expected %.15g, %.1f s)',ref{r,2},ref{r,3},v,ref{r,5},el),ok);
    end

    cases = {'AD3','DTLZ7',3,10; 'AD3','DTLZ7',6,10; 'AD1','WFG4',3,10; 'AD4','RWMOP30',2,25};
    for c = 1 : size(cases,1)
        vals = struct();
        for prof = {'final_A','final_B','final_AB','final_Brand'}
            if strcmp(cases{c,1},'AD4') && strcmp(prof{1},'final_Brand'), continue; end
            [s,el] = runOne(cases{c,1},prof{1},cases{c,2},cases{c,3},cases{c,4},smoke);
            ok = ~isempty(s);
            dead = NaN; cut = NaN; v = NaN;
            if ok
                if strcmp(cases{c,1},'AD4'), v = sum(s.finalObjs(:)); else, v = s.metric.IGDall; end
                X = s.metric.x1Diag; cols = s.metric.x1DiagCols;
                dead = mean(X(:,strcmp(cols,'deadNiches')),'omitnan'); cut = mean(X(:,strcmp(cols,'gapCut')),'omitnan');
                ok = isfinite(v);
            end
            vals.(prof{1}) = [v cut];
            nFail = nFail + report(sprintf('%-11s %-7s m=%d d=%d run 1: score %.6g, unreachable niches %.1f, cut edges %.1f (%.1f s)', ...
                prof{1},cases{c,2},cases{c,3},cases{c,4},v,dead,cut,el),ok);
        end
        if isfield(vals,'final_Brand') && isfield(vals,'final_B')
            b = vals.final_B; r = vals.final_Brand;
            nFail = nFail + report(sprintf('final_Brand vs final_B on %s m=%d: mean cut edges %.1f / %.1f, scores %.6g / %.6g (differ if edges are cut)', ...
                cases{c,2},cases{c,3},r(2),b(2),r(1),b(1)),(b(2) == 0 && r(2) == 0) || b(1) ~= r(1));
        end
    end

    for b = {'AD1','AD2','AD3','AD4'}, run_ac(b{1}); end      % dry run: 6480, 4320, 3600, 3150 tasks
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
    if ok, fprintf('%-110s OK\n',label); f = 0; else, fprintf('%-110s FAILED\n',label); f = 1; end
end
