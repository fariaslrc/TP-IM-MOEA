function run_smoke_test_te()
%RUN_SMOKE_TEST_TE  Installation check of phase TE (about 2 min). Every line must end in OK:
%   - 396 tasks (372 of D1 + 24 of F), 17 configurations, distinct output files;
%   - g15 and F on WFG4 (m = 3, d = 10, run 1) reproduce the article exactly (IGDall
%     0.441626967539076 and 0.409261289520922), and their times are printed.
%Writes only to Data_TE/_smoke/, deleted at the end.
    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot)); cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    smoke = fullfile(PlatEMORoot,'Data_TE','_smoke');
    if exist(smoke,'dir'), rmdir(smoke,'s'); end
    nFail = 0;
    T = te_build_tasks('TE1');
    nFail = nFail + report(sprintf('TE1: %d tasks (expected 396), %d configurations (expected 17), distinct outputs', ...
        numel(T),numel(unique({T.config}))),numel(T) == 396 && numel(unique({T.config})) == 17 && ...
        numel(unique({T.outFile})) == 396);
    ref = {'g15',0.441626967539076; 'F',0.409261289520922};
    for r = 1 : size(ref,1)
        k = find(strcmp({T.config},ref{r,1}) & strcmp({T.probName},'WFG4') & [T.M] == 3 & [T.D] == 10 & [T.run] == 1,1);
        t = T(k); [~,name] = fileparts(t.outFile);
        t.outFile = fullfile(smoke,ref{r,1},[name '.mat']);
        [s,el,note] = run_one_d_task(t);
        v = NaN; tm = NaN;
        if strcmp(s,'OK')
            S = load(t.outFile); v = S.metric.IGDall; tm = S.metric.tSolve;
        else
            fprintf('   %s: %s %s\n',ref{r,1},s,note);
        end
        nFail = nFail + report(sprintf('%-4s WFG4 m=3 run 1: IGDall %.15g (expected %.15g), optimization time %.2f s, task %.1f s', ...
            ref{r,1},v,ref{r,2},tm,el),abs(v - ref{r,2}) <= 1e-12);
    end
    run_te(true);
    if exist(smoke,'dir'), rmdir(smoke,'s'); end
    if nFail == 0, fprintf('\nAll smoke tests passed.\n'); else, fprintf('\n%d smoke test(s) FAILED.\n',nFail); end
end

function f = report(label,ok)
    if ok, fprintf('%-100s OK\n',label); f = 0; else, fprintf('%-100s FAILED\n',label); f = 1; end
end
