function run_u(dryRun)
%RUN_U  Phase U (see u_build_tasks), with the executor of phase D and the
%failure-tolerant run_one_g_task of phase G.
%   run_u             % block U1 (15 workers)
%   run_u(true)       % dry run: print the task count, run nothing
%   Output: Data_U/U1/<config>/<name>.mat. Resumable.

    if nargin < 1 || isempty(dryRun), dryRun = false; end
    tasks = u_build_tasks('U1');
    if dryRun
        fprintf('U1: %d tasks, %d configurations, %d distinct output files\n', ...
            numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
    else
        numWorkers = min(15,feature('numcores')-1);
        run_d_tasks(tasks,'U-U1',numWorkers,@run_one_g_task);
    end
end
