function run_c(blocks,dryRun)
%RUN_C  Phase C: protocol correction (see c_build_tasks).
%   run_c('C1')       % one block
%   run_c             % blocks C1..C5, C7 and C8 in order (C6 is cancelled)
%   run_c([],true)    % dry run: print task counts, run nothing
%   Output: Data_C/<block>/<config>/<name>.mat. Resumable.

    if nargin < 1 || isempty(blocks), blocks = {'C1','C2','C3','C4','C5','C7','C8'}; end
    if nargin < 2 || isempty(dryRun), dryRun = false; end
    if ischar(blocks), blocks = {blocks}; end
    total = 0;
    for b = 1:numel(blocks)
        tasks = c_build_tasks(blocks{b});
        if dryRun
            fprintf('%s: %d tasks, %d configurations, %d distinct output files\n',blocks{b}, ...
                numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
            total = total + numel(tasks);
        else
            run_c_tasks(tasks,['C-' blocks{b}]);
        end
    end
    if dryRun, fprintf('total: %d tasks\n',total); end
end
