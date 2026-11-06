function run_smoke_test_z10()
%RUN_SMOKE_TEST_Z10  Installation check of block Z10 of phase Z (about 1 min). Every line must end in OK:
%   - 1,620 tasks, topo = 4, the parameters of F (nbPhase 0.2, cellRead 1), distinct outputs;
%   - one task (WFG4, m = 3, d = 10, run 1) run with F and with g15 (block K1) on the same seed:
%     no error, finite scores.
%Writes only to Data_Z/_smoke/, deleted at the end.
    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot)); cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    smoke = fullfile(PlatEMORoot,'Data_Z','_smoke');
    if exist(smoke,'dir'), rmdir(smoke,'s'); end
    nFail = 0;
    T = z_build_tasks('Z10');
    ok = numel(T) == 1620 && numel(unique({T.outFile})) == 1620 && ...
         all(cellfun(@(p)isequal(p{14},4) && isequal(p{31},0.2) && isequal(p{42},1) && isempty(p{45}),{T.param}));
    nFail = nFail + report(sprintf('Z10: %d tasks (expected 1620), topo 4, parameters of F, distinct outputs',numel(T)),ok);
    k = find(strcmp({T.probName},'WFG4') & [T.M] == 3 & [T.D] == 10 & [T.run] == 1,1);
    t = T(k); g = t; g.param{31} = []; g.param{42} = [];
    [~,name] = fileparts(t.outFile);
    t.outFile = fullfile(smoke,'F',[name '.mat']); g.outFile = fullfile(smoke,'g15',[name '.mat']);
    [s1,e1,n1] = run_one_g_task(t); [s0,~,n0] = run_one_g_task(g);
    v1 = NaN; v0 = NaN;
    if strcmp(s1,'OK'), S = load(t.outFile); v1 = S.metric.IGDall; else, fprintf('   %s\n',n1); end
    if strcmp(s0,'OK'), S = load(g.outFile); v0 = S.metric.IGDall; else, fprintf('   %s\n',n0); end
    nFail = nFail + report(sprintf('Z10 WFG4 m=3 run 1: F %.6g, g15 %.6g (%.1f s)',v1,v0,e1),isfinite(v1) && isfinite(v0));
    run_z('Z10',true);
    if exist(smoke,'dir'), rmdir(smoke,'s'); end
    if nFail == 0, fprintf('\nAll smoke tests passed.\n'); else, fprintf('\n%d smoke test(s) FAILED.\n',nFail); end
end

function f = report(label,ok)
    if ok, fprintf('%-90s OK\n',label); f = 0; else, fprintf('%-90s FAILED\n',label); f = 1; end
end
