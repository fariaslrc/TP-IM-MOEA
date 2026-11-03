function run_x(dryRun)
%RUN_X  Phase X (see x_build_tasks), with the executor of phase D and the
%failure-tolerant run_one_g_task of phase G.
%   run_x             % block X1 (up to 15 workers)
%   run_x(true)       % dry run: print the task count, run nothing
%   Output: Data_X/X1/<config>/<name>.mat. Resumable.

    if nargin < 1 || isempty(dryRun), dryRun = false; end
    tasks = x_build_tasks('X1');
    if dryRun
        fprintf('X1: %d tasks, %d configurations, %d distinct output files\n', ...
            numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
    else
        numWorkers = min(15,feature('numcores')-1);
        run_d_tasks(tasks,'X-X1',numWorkers,@run_one_g_task);
    end
end
