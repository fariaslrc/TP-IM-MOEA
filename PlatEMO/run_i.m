function run_i(dryRun)
%RUN_I  Phase I (see i_build_tasks), with the executor of phase C.
%   run_i             % block I1
%   run_i(true)       % dry run: print the task count, run nothing
%   Output: Data_I/I1/<config>/<name>.mat. Resumable.

    if nargin < 1 || isempty(dryRun), dryRun = false; end
    tasks = i_build_tasks('I1');
    if dryRun
        fprintf('I1: %d tasks, %d configurations, %d distinct output files\n', ...
            numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
    else
        run_c_tasks(tasks,'I-I1');
    end
end
