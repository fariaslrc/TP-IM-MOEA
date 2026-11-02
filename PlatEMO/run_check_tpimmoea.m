function run_check_tpimmoea()
%RUN_CHECK_TPIMMOEA  Installation and reproduction check (about 1 min).
%Runs TPIMMOEA and TPIMMOEA_X with the final configuration on two instances
%of the article, with the seeds of the article, and compares their IGD of
%the nondominated solutions among all evaluations with the published runs:
%   WFG4,  m = 3, d = 10, run 1 (block C1)   IGD 0.441626967539076
%   DTLZ2, m = 3, d = 10, run 1 (block D2)   IGD 0.175080285833024
%Every line must end in OK. Writes only to Data_check/, deleted at the end.

    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    out   = fullfile(PlatEMORoot,'Data_check');
    nFail = 0;

    C1 = c_build_tasks('C1'); D2 = d_build_tasks('D2');
    sel = @(T,p) T(strcmp({T.config},'g15') & strcmp({T.probName},p) & [T.M] == 3 & [T.D] == 10 & [T.run] == 1);
    ref = {sel(C1,'WFG4'), 0.441626967539076
           sel(D2,'DTLZ2'),0.175080285833024};
    for i = 1 : size(ref,1)
        t = ref{i,1};
        [~,name] = fileparts(t.outFile);            % the seed is derived from this name
        for alg = {'TPIMMOEA_X','TPIMMOEA'}
            u = t;
            if strcmp(alg{1},'TPIMMOEA'), u.algName = 'TPIMMOEA'; u.param = {}; end
            u.outFile = fullfile(out,alg{1},[name '.mat']);
            [s,e,n] = run_one_c_task(u);
            if ~strcmp(s,'OK')
                nFail = nFail + 1;
                fprintf('%-11s %-6s FAILED: %s %s\n',alg{1},t.probName,s,n);
                continue;
            end
            S  = load(u.outFile);
            ok = abs(S.metric.IGDall - ref{i,2}) < 1e-12 && S.cfg.nRecorded == t.maxFE;
            fprintf('%-11s %-6s IGD=%.15g (expected %.15g, %.1f s)',alg{1},t.probName,S.metric.IGDall,ref{i,2},e);
            nFail = nFail + report(ok);
        end
    end
    if exist(out,'dir'), rmdir(out,'s'); end
    if nFail == 0
        fprintf('\nAll checks passed.\n');
    else
        fprintf('\n%d check(s) FAILED.\n',nFail);
    end
end

function f = report(ok)
    if ok, fprintf('  OK\n'); else, fprintf('  FAILED\n'); end
    f = double(~ok);
end
