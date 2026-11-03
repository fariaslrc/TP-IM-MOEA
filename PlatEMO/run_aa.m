function run_aa(dryRun)
%RUN_AA  Phase AA (see aa_build_tasks), with the executor of phase D and the
%failure-tolerant run_one_g_task of phase G.
%   run_aa            % block AA1 (up to 15 workers)
%   run_aa(true)       % dry run: print the task count, run nothing
%   Output: Data_A/AA1/<config>/<name>.mat. Resumable.

    if nargin < 1 || isempty(dryRun), dryRun = false; end
    tasks = aa_build_tasks('AA1');
    if dryRun
        fprintf('AA1: %d tasks, %d configurations, %d distinct output files\n', ...
            numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
    else
        numWorkers = min(15,feature('numcores')-1);
        run_d_tasks(tasks,'AA-AA1',numWorkers,@run_one_g_task);
    end
end
