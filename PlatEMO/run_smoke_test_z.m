function run_smoke_test_z()
%RUN_SMOKE_TEST_Z  Installation check of phase Z (about 10 min). Every line
%must end in OK:
%   - TPIMMOEA_X with the switch cellRead installed;
%   - the task counts of Z1 to Z9, cellRead = 1 in every task (except the g15
%     copies of Z9) and distinct output files;
%   - per block, one task run with and without cellRead on the same seed:
%     no error, a finite score, and a different score (the read-out acts).
%That g15 itself is unchanged is checked separately by run_check_tpimmoea.
%Writes only to Data_Z/_smoke/, deleted at the end.

    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    smoke = fullfile(PlatEMORoot,'Data_Z','_smoke');
    nFail = 0;

    src = fileread(fullfile(PlatEMORoot,'Algorithms','Multi-objective optimization','TPIMMOEA_X','TPIMMOEA_X.m'));
    nFail = nFail + report('TPIMMOEA_X with the switch cellRead installed',contains(src,'cellRead') && contains(src,'updatedNow'));

    expect = {'Z1',9720; 'Z2',3780; 'Z3',240; 'Z4',4860; 'Z5',3240; 'Z6',1800; 'Z7',1080; 'Z8',480; 'Z9',48};
    for b = 1 : size(expect,1)
        T  = z_build_tasks(expect{b,1});
        on = cellfun(@(p)isequal(p{42},1),{T.param});
        if strcmp(expect{b,1},'Z9')
            okc = sum(on) == 24 && all(on == strcmp({T.config},'X2'));
        else
            okc = all(on);
        end
        nFail = nFail + report(sprintf('%s: %d tasks (expected %d), cellRead set, distinct outputs',expect{b,1},numel(T),expect{b,2}), ...
            numel(T) == expect{b,2} && okc && numel(unique({T.outFile})) == numel(T));

        % one task with and without the read-out, on the same seed
        k = find(on & [T.run] == 1,1);
        cand = find(on & [T.run] == 1 & [T.M] == 3);
        if ~isempty(cand), k = cand(1); end
        t = T(k); g = t; g.param{42} = [];
        [~,name] = fileparts(t.outFile);
        t.outFile = fullfile(smoke,expect{b,1},'X2',[name '.mat']);
        g.outFile = fullfile(smoke,expect{b,1},'g15',[name '.mat']);
        [s1,e1,n1] = run_one_g_task(t);
        [s0,~,n0]  = run_one_g_task(g);
        if ~strcmp(s1,'OK') || ~strcmp(s0,'OK')
            nFail = nFail + 1;
            fprintf('%s %s FAILED: %s %s | %s %s\n',expect{b,1},t.probName,s1,n1,s0,n0);
            continue;
        end
        S1 = load(t.outFile); S0 = load(g.outFile);
        if strcmp(t.protocol,'all')
            v1 = S1.metric.IGDall; v0 = S0.metric.IGDall; lab = 'IGDall';
        else
            v1 = S1.metric.HV(end); v0 = S0.metric.HV(end); lab = 'HV';
        end
        fprintf('%s %s %s m=%d d=%d FE=%d: %s X2 %.6g, without the read-out %.6g (%.1fs)',expect{b,1},t.config,t.probName,t.M,t.D,t.maxFE,lab,v1,v0,e1);
        nFail = nFail + report('',isfinite(v1) && abs(v1 - v0) > 1e-12);
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
        fprintf('%-66s %s\n',label,s);
    end
    f = double(~ok);
end
