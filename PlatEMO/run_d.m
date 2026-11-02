function run_d(blocks,dryRun)
%RUN_D  Phase D: timing, held-out suite and remaining
%baselines (see d_build_tasks).
%   run_d('D1')       % one block; D1 always uses 4 workers (timing)
%   run_d             % blocks D1..D5 in order
%   run_d([],true)    % dry run: print task counts, run nothing
%   Output: Data_D/<block>/<config>/<name>.mat. Resumable.

    if nargin < 1 || isempty(blocks), blocks = {'D1','D2','D3','D4','D5'}; end
    if nargin < 2 || isempty(dryRun), dryRun = false; end
    if ischar(blocks), blocks = {blocks}; end
    total = 0;
    for b = 1:numel(blocks)
        tasks = d_build_tasks(blocks{b});
        if dryRun
            fprintf('%s: %d tasks, %d configurations, %d distinct output files\n',blocks{b}, ...
                numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
            total = total + numel(tasks);
        elseif strcmp(blocks{b},'D1')
            run_d_tasks(tasks,['D-' blocks{b}],4);
        else
            run_d_tasks(tasks,['D-' blocks{b}]);
        end
    end
    if dryRun, fprintf('total: %d tasks\n',total); end
end
