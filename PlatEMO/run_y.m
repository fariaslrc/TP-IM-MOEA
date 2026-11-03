function run_y(blocks,dryRun)
%RUN_Y  Phase Y (see y_build_tasks), with the executor of phase D and the
%failure-tolerant run_one_g_task of phase G.
%   run_y                 % blocks Y1, Y2 and Y3, in this order (up to 15 workers)
%   run_y('Y2')           % one block
%   run_y([],true)        % dry run: print the task counts, run nothing
%   Output: Data_Y/<block>/X2/<name>.mat. Resumable.

    if nargin < 1 || isempty(blocks), blocks = {'Y1','Y2','Y3'}; end
    if ischar(blocks), blocks = {blocks}; end
    if nargin < 2 || isempty(dryRun), dryRun = false; end
    for b = 1 : numel(blocks)
        tasks = y_build_tasks(blocks{b});
        if dryRun
            fprintf('%s: %d tasks, %d distinct output files\n',blocks{b},numel(tasks),numel(unique({tasks.outFile})));
        else
            numWorkers = min(15,feature('numcores')-1);
            run_d_tasks(tasks,['Y-' blocks{b}],numWorkers,@run_one_g_task);
        end
    end
end
