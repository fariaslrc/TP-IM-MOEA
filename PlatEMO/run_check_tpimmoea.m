function run_check_tpimmoea()
%RUN_CHECK_TPIMMOEA  Installation and reproduction check (about 2 min).
%Runs, with the seeds of the article, the public class TPIMMOEA (final configuration of the article)
%and TPIMMOEA_X with the previous configuration g15, and compares them with the published runs:
%   TPIMMOEA_X (g15)  WFG4  m=3 d=10 run 1 (block C1)    IGDall 0.441626967539076
%   TPIMMOEA_X (g15)  DTLZ2 m=3 d=10 run 1 (block D2)    IGDall 0.175080285833024
%   TPIMMOEA (final)  WFG4  m=3 d=10 run 1 (block X1)    IGDall 0.409261289520922  (ordering phase, cell read-out)
%   TPIMMOEA (final)  DTLZ2 m=3 d=10 run 1 (block AB3)   IGDall 0.143543680325121
%   TPIMMOEA (final)  RWMOP30 run 1, outN = 1 (block AC4) sum of the final objectives 46.5126200057014
%                                                         (exercises the repair; quadprog, relative tolerance 1e-9)
%Every line must end in OK. Writes only to Data_check/, deleted at the end.

    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    out   = fullfile(PlatEMORoot,'Data_check');
    nFail = 0;

    C1 = c_build_tasks('C1'); D2 = d_build_tasks('D2'); C5 = c_build_tasks('C5');
    sel = @(T,p) T(strcmp({T.config},'g15') & strcmp({T.probName},p) & [T.M] == 3 & [T.D] == 10 & [T.run] == 1);
    rw  = C5(strcmp({C5.config},'g15') & strcmp({C5.probName},'RWMOP30') & [C5.run] == 1);
    %      task          algorithm     reference           kind
    ref = {sel(C1,'WFG4'),  'TPIMMOEA_X', 0.441626967539076, 'igd'
           sel(D2,'DTLZ2'), 'TPIMMOEA_X', 0.175080285833024, 'igd'
           sel(C1,'WFG4'),  'TPIMMOEA',   0.409261289520922, 'igd'
           sel(D2,'DTLZ2'), 'TPIMMOEA',   0.143543680325121, 'igd'
           rw(1),           'TPIMMOEA',   46.5126200057014,  'sum'};
    for i = 1 : size(ref,1)
        t = ref{i,1}; u = t;
        [~,name] = fileparts(t.outFile);            % the seed is derived from this name
        if strcmp(ref{i,2},'TPIMMOEA')
            u.algName = 'TPIMMOEA';
            u.param = {};
            if strcmp(ref{i,4},'sum'), u.param = {[],[],[],[],[],[],[],[],1}; end   % outN = 1 on RWMOP
            lab = 'TPIMMOEA (final)';
        else
            lab = 'TPIMMOEA_X (g15)';
        end
        u.outFile = fullfile(out,sprintf('%d',i),[name '.mat']);
        [s,e,n] = run_one_c_task(u);
        if ~strcmp(s,'OK')
            nFail = nFail + 1;
            fprintf('%-17s %-7s FAILED: %s %s\n',lab,t.probName,s,n);
            continue;
        end
        S = load(u.outFile);
        if strcmp(ref{i,4},'igd')
            v  = S.metric.IGDall;
            ok = abs(v - ref{i,3}) < 1e-12 && S.cfg.nRecorded == t.maxFE;
            fprintf('%-17s %-7s IGD=%.15g (expected %.15g, %.1f s)',lab,t.probName,v,ref{i,3},e);
        else
            O  = S.result{end,2}.objs; v = sum(O(:));      % objs is a method: index its result, not the call
            ok = abs(v - ref{i,3}) <= 1e-9*abs(ref{i,3});
            fprintf('%-17s %-7s sum of final objectives=%.15g (expected %.15g, %.1f s)',lab,t.probName,v,ref{i,3},e);
        end
        nFail = nFail + report(ok);
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
