function run_p3(blocks,dryRun)
%RUN_P3  Phase P3 (see p3_build_tasks): per-run data of the baselines.
%
%   run_p3('P1')         % one block (see p3_build_tasks for P1..P8)
%   run_p3               % blocks P1..P7 in order (P8 = CSEA only on request)
%   run_p3([],true)      % dry run: print task counts, run nothing
%
%   Output: Data_P3/<block>/<config>/<name>.mat. Resumable.

    if nargin < 1 || isempty(blocks), blocks = {'P1','P2','P3','P4','P5','P6','P7'}; end
    if nargin < 2 || isempty(dryRun), dryRun = false; end
    if ischar(blocks), blocks = {blocks}; end
    total = 0;
    for b = 1:numel(blocks)
        tasks = p3_build_tasks(blocks{b});
        if dryRun
            fprintf('%s: %d tasks, %d configurations, %d distinct output files\n',blocks{b}, ...
                numel(tasks),numel(unique({tasks.config})),numel(unique({tasks.outFile})));
            total = total + numel(tasks);
        else
            run_n50_tasks(tasks,['P3-' blocks{b}]);
        end
    end
    if dryRun, fprintf('total: %d tasks\n',total); end
end
