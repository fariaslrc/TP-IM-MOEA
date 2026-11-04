function run_smoke_test_ab()
%RUN_SMOKE_TEST_AB  Installation check of phase AB (about 5 min). Every line
%must end in OK:
%   - TPIMMOEA_X with the switch cellRead installed;
%   - the task lists: 1,080 (AB1), 1,050 (AB2) and 900 (AB3) tasks, cellRead = 1, nbPhase = 0.2
%     and every other parameter equal to those of the g15 task of the same name;
%   - one run per block (WFG4 with m = 15, RWMOP1 and DTLZ2 with m = 3,
%     d = 10, run 1): no error, a finite score, and a score different from
%     that of g15 on the same seed (otherwise the switch had no effect).
%That g15 itself is unchanged is checked separately by run_check_tpimmoea.
%Writes only to Data_A/_smoke/, deleted at the end.

    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    smoke = fullfile(PlatEMORoot,'Data_A','_smoke');
    nFail = 0;

    src = fileread(fullfile(PlatEMORoot,'Algorithms','Multi-objective optimization','TPIMMOEA_X','TPIMMOEA_X.m'));
    nFail = nFail + report('TPIMMOEA_X with the switch cellRead installed',contains(src,'cellRead') && contains(src,'updatedNow'));

    ref   = {'AB1',c_build_tasks('C2'),1080,'WFG4',15; 'AB2',c_build_tasks('C5'),1050,'RWMOP1',2; 'AB3',d_build_tasks('D2'),900,'DTLZ2',3};
    for b = 1 : size(ref,1)
        T = ab_build_tasks(ref{b,1});
        G = ref{b,2}; G = G(strcmp({G.config},'g15'));
        same = numel(T) == ref{b,3} && numel(G) == numel(T);
        for i = 1 : numel(T)
            q = T(i).param; q0 = G(i).param; q0(end+1:42) = {[]};
            [~,n1] = fileparts(T(i).outFile); [~,n0] = fileparts(G(i).outFile);
            same = same && isequal(q([1:30 32:41]),q0([1:30 32:41])) && isequal(q{31},0.2) && isequal(q{42},1) && strcmp(n1,n0);
        end
        nFail = nFail + report(sprintf('%s: %d tasks, nbPhase 0.2, cellRead 1, rest and names as g15',ref{b,1},numel(T)),same);

        k = find(strcmp({T.probName},ref{b,4}) & [T.M] == ref{b,5} & [T.run] == 1,1);
        t = T(k); g = G(k);
        [~,name] = fileparts(t.outFile);
        g.outFile = fullfile(smoke,'g15',[name '.mat']);
        t.outFile = fullfile(smoke,'X1',[name '.mat']);
        run_one_c_task(g);
        [s,e,n] = run_one_g_task(t);
        if ~strcmp(s,'OK')
            nFail = nFail + 1;
            fprintf('%s %s FAILED: %s %s\n',ref{b,1},t.probName,s,n);
            continue;
        end
        S0 = load(g.outFile); S1 = load(t.outFile);
        if strcmp(t.protocol,'all')
            v0 = S0.metric.IGDall; v1 = S1.metric.IGDall; lab = 'IGDall';
        else
            v0 = S0.metric.HV(end); v1 = S1.metric.HV(end); lab = 'HV';
        end
        fprintf('%s %s m=%d d=%d: %s X1 %.6g, g15 %.6g (%.1fs)',ref{b,1},t.probName,t.M,t.D,lab,v1,v0,e);
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
