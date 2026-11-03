function run_smoke_test_aa()
%RUN_SMOKE_TEST_AA  Installation check of phase AA (about 3 min). Every line
%must end in OK:
%   - TPIMMOEA_X with the switches batchOne and arcCap installed;
%   - the task list of AA1: 6,480 tasks, 4 configurations, the switches of
%     each configuration;
%   - one run of every configuration on WFG4 with (m,d) = (3,10) and (9,100),
%     run 1: no error, 300 evaluations, a finite IGD, the expected archive
%     (100 members, or 300 with arcCap), and an IGD equal to that of g15 on the
%     same seed for AA0 and different from it in at least one run otherwise.
%Writes only to Data_A/_smoke/, deleted at the end.

    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    smoke = fullfile(PlatEMORoot,'Data_A','_smoke');
    nFail = 0;

    src = fileread(fullfile(PlatEMORoot,'Algorithms','Multi-objective optimization','TPIMMOEA_X','TPIMMOEA_X.m'));
    nFail = nFail + report('TPIMMOEA_X with the switches batchOne and arcCap installed', ...
        contains(src,'batchOne') && contains(src,'arcCap') && contains(src,'nPool'));

    T   = aa_build_tasks('AA1');
    cfg = unique({T.config},'stable');
    nFail = nFail + report(sprintf('AA1 task count %d (expected 6480)',numel(T)),numel(T) == 6480);
    nFail = nFail + report('AA1 distinct output files',numel(unique({T.outFile})) == numel(T));
    expect = {'AA0_g15',0,0; 'AA1_batch1',1,0; 'AA2_arc300',0,300; 'AA3_both',1,300};
    okCfg = numel(cfg) == 4;
    for v = 1 : size(expect,1)
        P = {T(strcmp({T.config},expect{v,1})).param};
        okCfg = okCfg && numel(P) == 1620 && all(cellfun(@(p)isequal(p(43:44),expect(v,2:3)),P));
    end
    nFail = nFail + report('batchOne and arcCap of every configuration',okCfg);

    C1  = c_build_tasks('C1');
    ref = containers.Map();
    for md = [3 10; 9 100]'
        t = C1(strcmp({C1.config},'g15') & strcmp({C1.probName},'WFG4') & [C1.M] == md(1) & [C1.D] == md(2) & [C1.run] == 1);
        [~,name] = fileparts(t.outFile);
        t.outFile = fullfile(smoke,'g15',[name '.mat']);
        run_one_c_task(t);
        S = load(t.outFile);
        ref(sprintf('%d_%d',md)) = S.metric.IGDall;
    end
    for c = 1 : numel(cfg)
        differs = false; okRuns = true; same = true;
        for md = [3 10; 9 100]'
            t = T(strcmp({T.config},cfg{c}) & strcmp({T.probName},'WFG4') & [T.M] == md(1) & [T.D] == md(2) & [T.run] == 1);
            [~,name] = fileparts(t.outFile);
            t.outFile = fullfile(smoke,cfg{c},[name '.mat']);
            [s,e,n] = run_one_g_task(t);
            if ~strcmp(s,'OK')
                okRuns = false; fprintf('%-11s m=%d FAILED: %s %s\n',cfg{c},md(1),s,n); continue;
            end
            S = load(t.outFile); g = ref(sprintf('%d_%d',md));
            arcExp = 100; if t.param{44} > 0, arcExp = t.param{44}; end
            okRuns  = okRuns && S.cfg.nRecorded == 300 && isfinite(S.metric.IGDall) && S.cfg.archiveSize == arcExp;
            differs = differs || abs(S.metric.IGDall - g) > 1e-12;
            same    = same && S.metric.IGDall == g;
            fprintf('%-11s m=%d IGDall=%.6g (g15 %.6g), archive %d, %.1fs\n',cfg{c},md(1),S.metric.IGDall,g,S.cfg.archiveSize,e);
        end
        if strcmp(cfg{c},'AA0_g15'), ok = okRuns && same; else, ok = okRuns && differs; end
        nFail = nFail + report(sprintf('%s: runs complete, archive as expected, IGD as expected',cfg{c}),ok);
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
    fprintf('%-66s %s\n',label,s);
    f = double(~ok);
end
