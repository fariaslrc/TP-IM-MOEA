function run_g(blocks,dryRun)
%RUN_G  Phase G (see g_build_tasks), with the executor of phase D and the
%failure-tolerant run_one_g_task.
%   run_g('G1')       % one block
%   run_g             % G1, G2 and G3
%   run_g([],true)    % dry run: print task counts, run nothing
%   Output: Data_G/<block>/<config>/<name>.mat. Resumable.

    if nargin < 1 || isempty(blocks), blocks = {'G1','G2','G3'}; end
    if nargin < 2 || isempty(dryRun), dryRun = false; end
    if ischar(blocks), blocks = {blocks}; end
    total = 0;
    for b = 1:numel(blocks)
        tasks = g_build_tasks(blocks{b});
        if dryRun
            fprintf('%s: %d tasks, %d configurations, %d distinct output files\n',blocks{b}, ...
                numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
            total = total + numel(tasks);
        else
            run_d_tasks(tasks,['G-' blocks{b}],[],@run_one_g_task);
        end
    end
    if dryRun, fprintf('total: %d tasks\n',total); end
end
