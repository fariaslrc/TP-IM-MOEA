function run_h(blocks,dryRun)
%RUN_H  Phase H (see h_build_tasks), with the executor of phase D and the
%failure-tolerant run_one_g_task of phase G.
%   run_h('H1')       % one block
%   run_h             % H1, H3 and H2, in this order (15 workers)
%   run_h([],true)    % dry run: print task counts, run nothing
%   Output: Data_H/<block>/<config>/<name>.mat. Resumable.

    if nargin < 1 || isempty(blocks), blocks = {'H1','H3','H2'}; end
    numWorkers = min(15,feature('numcores')-1);      % the long SAEA runs dominate: one core is left free
    if nargin < 2 || isempty(dryRun), dryRun = false; end
    if ischar(blocks), blocks = {blocks}; end
    total = 0;
    for b = 1:numel(blocks)
        tasks = h_build_tasks(blocks{b});
        if dryRun
            fprintf('%s: %d tasks, %d configurations, %d distinct output files\n',blocks{b}, ...
                numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
            total = total + numel(tasks);
        else
            run_d_tasks(tasks,['H-' blocks{b}],numWorkers,@run_one_g_task);
        end
    end
    if dryRun, fprintf('total: %d tasks\n',total); end
end
