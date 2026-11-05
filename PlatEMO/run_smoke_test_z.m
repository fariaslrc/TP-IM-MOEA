function run_smoke_test_z()
%RUN_SMOKE_TEST_Z  Installation check of phase Z, version 2 (final model F of phase AC), about
%10 min. Every line must end in OK:
%   - task counts of Z1 to Z9, distinct output files, and the parameters of F in every task
%     (nbPhase 0.2 and cellRead 1; parameter 45 = gated_repair_global on RWMOP, empty elsewhere;
%     the g15 copies of Z9 unchanged);
%   - F through the phase AC path (parameter 45 set) equals X1 through the historical path on
%     WFG4 (m = 3, d = 10, run 1), and both reproduce phase X (IGDall 0.409261289520922);
%   - one run (run 1) of EVERY configuration of every block: no error and a finite score; per
%     block, one configuration is also run as g15 on the same seed and must differ (F acts).
%     q01_noRefMap and q06_noSOM are reported against their g15 runs for information only: F may
%     coincide with g15 there, because the anchored map or its read-out is switched off.
%Writes only to Data_Z/_smoke/, deleted at the end.

    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    smoke = fullfile(PlatEMORoot,'Data_Z','_smoke');
    if exist(smoke,'dir'), rmdir(smoke,'s'); end
    nFail = 0;
    opt = x1_options('gated_repair_global');

    expect = {'Z1',12960; 'Z2',3780; 'Z3',240; 'Z4',6480; 'Z5',3240; 'Z6',1800; 'Z7',1080; 'Z8',480; 'Z9',48};
    for b = 1 : size(expect,1)
        T = z_build_tasks(expect{b,1});
        isF = ~strcmp({T.config},'g15');
        okp = true;
        for i = 1 : numel(T)
            p = T(i).param;
            if isF(i)
                rw = startsWith(T(i).probName,'RWMOP');
                okp = okp && isequal(p{31},0.2) && isequal(p{42},1) && numel(p) == 45 && ...
                      ((rw && isequal(p{45},opt)) || (~rw && isempty(p{45})));
            else
                okp = okp && isempty(p{45}) && ~isequal(p{42},1);
            end
        end
        nFail = nFail + report(sprintf('%s: %d tasks (expected %d), parameters of F, distinct outputs',expect{b,1},numel(T),expect{b,2}), ...
            numel(T) == expect{b,2} && okp && numel(unique({T.outFile})) == numel(T));
    end

    % F through the phase AC path equals X1 through the historical path
    C = c_build_tasks('C1'); C = C(strcmp({C.config},'g15') & strcmp({C.probName},'WFG4') & [C.M] == 3 & [C.D] == 10 & [C.run] == 1);
    t = C(1); t.param(end+1:45) = {[]}; t.param{31} = 0.2; t.param{42} = 1;
    a = t; a.param{45} = opt; [~,name] = fileparts(t.outFile);
    t.outFile = fullfile(smoke,'eq','X1',[name '.mat']); a.outFile = fullfile(smoke,'eq','F',[name '.mat']);
    v1 = runScore(t); v2 = runScore(a);
    nFail = nFail + report(sprintf('F (AC path) = X1 (historical path) on WFG4 m=3 run 1: %.15g / %.15g',v2,v1), ...
        isfinite(v1) && v1 == v2 && abs(v1 - 0.409261289520922) <= 1e-12);

    % one run of every configuration; one difference check against g15 per block
    for b = 1 : size(expect,1)
        T = z_build_tasks(expect{b,1});
        cfgs = unique({T.config}); cfgs = cfgs(~strcmp(cfgs,'g15'));
        diffDone = false;
        for c = 1 : numel(cfgs)
            S = T(strcmp({T.config},cfgs{c}) & [T.run] == 1);
            k = find([S.M] == 3,1); if isempty(k), k = 1; end
            t = S(k); [~,name] = fileparts(t.outFile);
            t.outFile = fullfile(smoke,expect{b,1},cfgs{c},[name '.mat']);
            [v,el] = runScore(t);
            line = sprintf('%s %-18s %-7s m=%d d=%d FE=%d: F %.6g (%.1f s)',expect{b,1},cfgs{c},t.probName,t.M,t.D,t.maxFE,v,el);
            ok = isfinite(v);
            special = ismember(cfgs{c},{'q01_noRefMap','q06_noSOM'});
            if ok && (special || ~diffDone)
                g = t; g.param = g.param; g.param{31} = []; g.param{42} = []; g.param{45} = [];
                g.outFile = fullfile(smoke,expect{b,1},[cfgs{c} '_g15'],[name '.mat']);
                v0 = runScore(g);
                if special
                    line = sprintf('%s, g15 %.6g (%s, information)',line,v0,ternary(v == v0,'equal','different'));
                else
                    line = sprintf('%s, g15 %.6g',line,v0); ok = isfinite(v0) && abs(v - v0) > 1e-12; diffDone = true;
                end
            end
            nFail = nFail + report(line,ok);
        end
    end

    run_z([],true);                                           % dry run: task counts
    if exist(smoke,'dir'), rmdir(smoke,'s'); end
    if nFail == 0
        fprintf('\nAll smoke tests passed.\n');
    else
        fprintf('\n%d smoke test(s) FAILED. Do not launch the batch yet.\n',nFail);
    end
end

function [v,el] = runScore(t)
    v = NaN;
    if exist(t.outFile,'file') == 2, delete(t.outFile); end
    [s,el,note] = run_one_g_task(t);
    if ~strcmp(s,'OK'), fprintf('   %s %s: %s %s\n',t.config,t.probName,s,note); return; end
    S = load(t.outFile);
    if strcmp(t.protocol,'all'), v = S.metric.IGDall;
    else, h = S.metric.HV; h = h(~isnan(h)); if isempty(h), v = 0; else, v = h(end); end
    end
end

function s = ternary(c,a,b)
    if c, s = a; else, s = b; end
end

function f = report(label,ok)
    if ok, fprintf('%-110s OK\n',label); f = 0; else, fprintf('%-110s FAILED\n',label); f = 1; end
end
