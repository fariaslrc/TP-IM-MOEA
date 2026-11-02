function run_k(dryRun)
%RUN_K  Phase K (see k_build_tasks), with the executor of phase C.
%   run_k             % block K1
%   run_k(true)       % dry run: print the task count, run nothing
%   Output: Data_K/K1/q06b_noSOM/<name>.mat. Resumable.

    if nargin < 1 || isempty(dryRun), dryRun = false; end
    tasks = k_build_tasks('K1');
    if dryRun
        fprintf('K1: %d tasks, %d configurations, %d distinct output files\n', ...
            numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
    else
        run_c_tasks(tasks,'K-K1');
    end
end
