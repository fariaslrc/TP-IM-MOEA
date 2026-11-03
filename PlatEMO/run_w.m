function run_w(dryRun)
%RUN_W  Phase W (see w_build_tasks), with the executor of phase D and the
%failure-tolerant run_one_g_task of phase G.
%   run_w             % block W1 (up to 15 workers)
%   run_w(true)       % dry run: print the task count, run nothing
%   Output: Data_W/W1/<config>/<name>.mat. Resumable.

    if nargin < 1 || isempty(dryRun), dryRun = false; end
    tasks = w_build_tasks('W1');
    if dryRun
        fprintf('W1: %d tasks, %d configurations, %d distinct output files\n', ...
            numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
    else
        numWorkers = min(15,feature('numcores')-1);
        run_d_tasks(tasks,'W-W1',numWorkers,@run_one_g_task);
    end
end
