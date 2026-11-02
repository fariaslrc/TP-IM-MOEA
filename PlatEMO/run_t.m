function run_t(dryRun)
%RUN_T  Phase T (see t_build_tasks), with the executor of phase D and the
%failure-tolerant run_one_g_task of phase G.
%   run_t             % block T1 (15 workers)
%   run_t(true)       % dry run: print the task count, run nothing
%   Output: Data_T/T1/<config>/<name>.mat. Resumable.

    if nargin < 1 || isempty(dryRun), dryRun = false; end
    tasks = t_build_tasks('T1');
    if dryRun
        fprintf('T1: %d tasks, %d configurations, %d distinct output files\n', ...
            numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
    else
        numWorkers = min(15,feature('numcores')-1);
        run_d_tasks(tasks,'T-T1',numWorkers,@run_one_g_task);
    end
end
