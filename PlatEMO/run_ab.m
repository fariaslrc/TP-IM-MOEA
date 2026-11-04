function run_ab(blocks,dryRun)
%RUN_AB  Phase AB (see ab_build_tasks), with the executor of phase D and the
%failure-tolerant run_one_g_task of phase G.
%   run_ab                % blocks AB1, AB2 and AB3, in this order (up to 15 workers)
%   run_ab('AB2')          % one block
%   run_ab([],true)        % dry run: print the task counts, run nothing
%   Output: Data_A/<block>/X1/<name>.mat. Resumable.

    if nargin < 1 || isempty(blocks), blocks = {'AB1','AB2','AB3'}; end
    if ischar(blocks), blocks = {blocks}; end
    if nargin < 2 || isempty(dryRun), dryRun = false; end
    for b = 1 : numel(blocks)
        tasks = ab_build_tasks(blocks{b});
        if dryRun
            fprintf('%s: %d tasks, %d distinct output files\n',blocks{b},numel(tasks),numel(unique({tasks.outFile})));
        else
            numWorkers = min(15,feature('numcores')-1);
            run_d_tasks(tasks,['AB-' blocks{b}],numWorkers,@run_one_g_task);
        end
    end
end
