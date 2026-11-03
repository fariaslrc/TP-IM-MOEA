function run_z(blocks,dryRun)
%RUN_Z  Phase Z (see z_build_tasks), with the executor of phase D and the
%failure-tolerant run_one_g_task of phase G. Z9 (time) runs first, alone and
%with 4 workers; the other blocks use up to 15 workers.
%   run_z                 % Z9, then Z1 to Z8
%   run_z('Z4')           % one block
%   run_z([],true)        % dry run: print the task counts, run nothing
%   Output: Data_Z/<block>/<config>/<name>.mat. Resumable.

    if nargin < 1 || isempty(blocks), blocks = {'Z9','Z1','Z2','Z3','Z4','Z5','Z6','Z7','Z8'}; end
    if ischar(blocks), blocks = {blocks}; end
    if nargin < 2 || isempty(dryRun), dryRun = false; end
    for b = 1 : numel(blocks)
        tasks = z_build_tasks(blocks{b});
        if dryRun
            fprintf('%s: %d tasks, %d configurations, %d distinct output files\n',blocks{b},numel(tasks), ...
                numel(unique({tasks.config})),numel(unique({tasks.outFile})));
        else
            if strcmp(blocks{b},'Z9'), numWorkers = 4; else, numWorkers = min(15,feature('numcores')-1); end
            run_d_tasks(tasks,['Z-' blocks{b}],numWorkers,@run_one_g_task);
        end
    end
end
