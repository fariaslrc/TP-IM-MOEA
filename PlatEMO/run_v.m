function run_v(dryRun)
%RUN_V  Phase V (see v_build_tasks), with the executor of phase D and the
%failure-tolerant run_one_g_task of phase G.
%   run_v             % block V1 (up to 15 workers)
%   run_v(true)       % dry run: print the task count, run nothing
%   Output: Data_V/V1/<config>/<name>.mat. Resumable.

    if nargin < 1 || isempty(dryRun), dryRun = false; end
    tasks = v_build_tasks('V1');
    if dryRun
        fprintf('V1: %d tasks, %d configurations, %d distinct output files\n', ...
            numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
    else
        numWorkers = min(15,feature('numcores')-1);
        run_d_tasks(tasks,'V-V1',numWorkers,@run_one_g_task);
    end
end
