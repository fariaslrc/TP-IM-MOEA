function report = test_ac_resume()
%TEST_AC_RESUME Synthetic MAT-file integrity tests; zero problem evaluations.
    tasks = ac_build_tasks('AC_A',{'legacy'},1);
    t = tasks(1); source = struct('digest','synthetic-source'); %#ok<NASGU>
    cfg = struct('taskHash',ac_task_identity(t,source.digest),'sourceDigest',source.digest, ...
        'status','COMPLETE','nRecorded',t.maxFE,'FE',t.maxFE,'problemN',t.N,'archiveSize',2*t.N); %#ok<NASGU>
    metric = struct('IGDall',1,'firstFeasibleFE',1,'everFeasible',true, ...
        'finalFeasible',true,'nFinalFeasible',2*t.N,'minFinalCV',0,'tSolve',0); %#ok<NASGU>
    finalObjs = ones(2*t.N,t.M); finalCons = zeros(2*t.N,1); %#ok<NASGU>
    recObjs = ones(t.maxFE,t.M); recCons = zeros(t.maxFE,1); %#ok<NASGU>
    file = [tempname,'.mat']; cleanup = onCleanup(@()removeOwnFile(file)); %#ok<NASGU>
    save(file,'cfg','metric','finalObjs','finalCons','recObjs','recCons','source');
    assert(ac_result_matches(file,t,source.digest),'AC:Test','Valid synthetic result rejected.');
    mutated = t; mutated.param{31} = mutated.param{31}+0.01;
    assert(~ac_result_matches(file,mutated,source.digest),'AC:Test','Mutated configuration accepted.');
    save(file,'cfg','metric','finalObjs','finalCons','recCons','source');
    assert(~ac_result_matches(file,t,source.digest),'AC:Test','Missing objective records accepted.');
    recObjs = ones(t.maxFE-1,t.M); %#ok<NASGU>
    save(file,'cfg','metric','finalObjs','finalCons','recObjs','recCons','source');
    assert(~ac_result_matches(file,t,source.digest),'AC:Test','Truncated objective records accepted.');
    recObjs = ones(t.maxFE,t.M); recCons = zeros(t.maxFE-1,1); %#ok<NASGU>
    save(file,'cfg','metric','finalObjs','finalCons','recObjs','recCons','source');
    assert(~ac_result_matches(file,t,source.digest),'AC:Test','Truncated constraint records accepted.');
    recCons = zeros(t.maxFE,1); %#ok<NASGU>
    save(file,'cfg','metric','finalObjs','finalCons','recObjs','recCons');
    assert(~ac_result_matches(file,t,source.digest),'AC:Test','Missing source manifest accepted.');
    finalObjs(1,1) = NaN;
    save(file,'cfg','metric','finalObjs','finalCons','recObjs','recCons','source');
    assert(~ac_result_matches(file,t,source.digest),'AC:Test','Nonfinite reported objectives accepted.');
    finalObjs = ones(2*t.N,t.M-1); %#ok<NASGU>
    save(file,'cfg','metric','finalObjs','finalCons','recObjs','recCons','source');
    assert(~ac_result_matches(file,t,source.digest),'AC:Test','Incorrect objective dimension accepted.');
    report = struct('passed',true,'zeroEvaluations',true,'checks',8);
    fprintf('AC resume checks passed: 8 synthetic integrity cases, ZERO evaluations.\n');
end

function removeOwnFile(file)
    if exist(file,'file') == 2, delete(file); end
end
