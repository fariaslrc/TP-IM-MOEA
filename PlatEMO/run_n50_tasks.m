function run_n50_tasks(tasks,label)
%RUN_N50_TASKS  Resumable parallel executor (N = 50 rerun and round 5). A
%task is skipped only when its output file exists AND records the task's N
%(cfg.N and Problem.N) with a full archive (2N); any other file at that
%path is rerun and overwritten.

    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);

    keep = true(1,numel(tasks));
    for i = 1:numel(tasks)
        f = tasks(i).outFile;
        if exist(f,'file') == 2
            try
                S = load(f,'cfg');
                n = tasks(i).N;
                checkArc = ~isfield(tasks(i),'checkArchive') || tasks(i).checkArchive;
                if S.cfg.N == n && (~checkArc || (S.cfg.problemN == n && S.cfg.archiveSize == 2*n))
                    keep(i) = false;
                end
            catch
            end
        end
    end
    fprintf('[%s] Total tasks: %d. Already done (skipped): %d. Remaining: %d.\n', ...
        label,numel(tasks),sum(~keep),sum(keep));
    tasks = tasks(keep);
    if isempty(tasks)
        fprintf('[%s] Nothing to do.\n',label);
        return;
    end

    numWorkers = 10;
    BATCH_SIZE = 250;

    n = numel(tasks);
    okCount = 0; errCount = 0; t0 = tic;
    done = 0;
    while done < n
        batch = tasks((done+1):min(done+BATCH_SIZE,n));

        pool = gcp('nocreate');
        if isempty(pool)
            c = parcluster('local');
            if c.NumWorkers < numWorkers
                c.NumWorkers = numWorkers;
                saveProfile(c);
            end
            pool = parpool(c,numWorkers);
            pctRunOnAll(sprintf('addpath(genpath(''%s''));',strrep(PlatEMORoot,'''','''''')));
        end

        nb = numel(batch);
        futures(nb) = parallel.FevalFuture; %#ok<AGROW>
        for i = 1:nb
            futures(i) = parfeval(pool,@run_one_n50_task,3,batch(i));
        end

        for k = 1:nb
            [idx,status,elapsed,note] = fetchNext(futures);
            t = batch(idx);
            if strcmp(status,'OK'), okCount = okCount + 1; else, errCount = errCount + 1; end
            fprintf('[%s %d/%d, %.1f min] %s %s (M=%d,D=%d,FE=%d) %s run %d: %s (%.1fs) %s\n', ...
                label,done+k,n,toc(t0)/60,t.algName,t.probName,t.M,t.D,t.maxFE,t.config,t.run,status,elapsed,note);
        end
        clear futures

        done = done + nb;
        delete(gcp('nocreate'));
    end

    fprintf('\n[%s] finished in %.1f min. total=%d ok=%d error=%d\n', ...
        label,toc(t0)/60,n,okCount,errCount);
end
