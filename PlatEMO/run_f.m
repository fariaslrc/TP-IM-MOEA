function run_f(blocks,dryRun)
%RUN_F  Phase F (see f_build_tasks), with the executor of phase D.
%   run_f('F1')       % one block
%   run_f             % F1 and F2
%   run_f([],true)    % dry run: print task counts, run nothing
%   Output: Data_F/<block>/<config>/<name>.mat. Resumable.

    if nargin < 1 || isempty(blocks), blocks = {'F1','F2'}; end
    if nargin < 2 || isempty(dryRun), dryRun = false; end
    if ischar(blocks), blocks = {blocks}; end
    total = 0;
    for b = 1:numel(blocks)
        tasks = f_build_tasks(blocks{b});
        if dryRun
            fprintf('%s: %d tasks, %d configurations, %d distinct output files\n',blocks{b}, ...
                numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
            total = total + numel(tasks);
        else
            run_d_tasks(tasks,['F-' blocks{b}]);
        end
    end
    if dryRun, fprintf('total: %d tasks\n',total); end
end
