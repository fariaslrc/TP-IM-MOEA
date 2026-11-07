function run_te(dryRun)
%RUN_TE  Phase TE (time): block TE1 with 4 workers, all algorithms shuffled together.
%   run_te          % run (resumable)
%   run_te(true)    % dry run: task counts only
    if nargin < 1 || isempty(dryRun), dryRun = false; end
    tasks = te_build_tasks('TE1');
    if dryRun
        cfg = unique({tasks.config});
        fprintf('TE1: %d tasks, %d configurations, %d distinct output files\n',numel(tasks),numel(cfg), ...
            numel(unique({tasks.outFile})));
        return;
    end
    run_d_tasks(tasks,'TE-TE1',4);
end
