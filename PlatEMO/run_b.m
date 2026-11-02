function run_b(blocks,dryRun)
%RUN_B  Phase B: further baselines on the WFG grid (see b_build_tasks).
%   run_b('B1')       % one block
%   run_b             % blocks B1..B4 in order
%   run_b([],true)    % dry run: print task counts, run nothing
%   Output: Data_B/<block>/<alg>/<name>.mat. Resumable.

    if nargin < 1 || isempty(blocks), blocks = {'B1','B2','B3','B4'}; end
    if nargin < 2 || isempty(dryRun), dryRun = false; end
    if ischar(blocks), blocks = {blocks}; end
    total = 0;
    for b = 1:numel(blocks)
        tasks = b_build_tasks(blocks{b});
        if dryRun
            fprintf('%s: %d tasks, %d configurations, %d distinct output files\n',blocks{b}, ...
                numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
            total = total + numel(tasks);
        else
            run_n50_tasks(tasks,['B-' blocks{b}]);
        end
    end
    if dryRun, fprintf('total: %d tasks\n',total); end
end
