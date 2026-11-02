function run_d_tasks(tasks,label,numWorkers,runner)
%RUN_D_TASKS  Resumable parallel executor of phase D (run_c_tasks of phase C
%with run_one_d_task and a configurable number of workers, by default the
%number of cores up to 10). runner, by default @run_one_d_task, is the
%worker-side function (phase G passes @run_one_g_task). A task is skipped
%only when its output file exists and records the task's N and protocol;
%any other file at that path is rerun and overwritten.
    if nargin < 4 || isempty(runner), runner = @run_one_d_task; end

    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot));
    cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');     % CPU only: the workers inherit it

    keep = true(1,numel(tasks));
    for i = 1:numel(tasks)
        f = tasks(i).outFile;
        if exist(f,'file') == 2
            try
                S = load(f,'cfg');
                if S.cfg.N == tasks(i).N && isfield(S.cfg,'protocol') && strcmp(S.cfg.protocol,tasks(i).protocol)
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

    if nargin < 3 || isempty(numWorkers)
        numWorkers = min(10,feature('numcores'));
    end
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
            if any(fetchOutputs(parfevalOnAll(pool,@canUseGPU,1)))
                error('A GPU is visible to the workers. Start MATLAB with CUDA_VISIBLE_DEVICES=-1 (see the README).');
            end
        end

        nb = numel(batch);
        futures(nb) = parallel.FevalFuture; %#ok<AGROW>
        for i = 1:nb
            futures(i) = parfeval(pool,runner,3,batch(i));
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
