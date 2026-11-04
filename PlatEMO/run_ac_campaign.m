function run_ac_campaign(blocks,numWorkers)
%RUN_AC_CAMPAIGN  Phase AC (lean version 2) on CASA: AC1, AC2, AC3 and AC4 in this order, runs 1:30.
%   run_ac_campaign                 % every block, min(15, cores-1) workers
%   run_ac_campaign({'AC4'})        % one block
%Resumable: completed runs with the same identity are skipped. The first task error stops the
%block (run_ac); rerun the same command to resume.
    if nargin < 1 || isempty(blocks), blocks = {'AC1','AC2','AC3','AC4'}; end
    if ischar(blocks), blocks = {blocks}; end
    if nargin < 2 || isempty(numWorkers), numWorkers = min(15,feature('numcores')-1); end
    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot)); cd(PlatEMORoot);
    setenv('CUDA_VISIBLE_DEVICES','-1');
    ac_check_host();
    pool = gcp('nocreate');
    if ~isempty(pool) && pool.NumWorkers ~= numWorkers, delete(pool); pool = []; end
    if isempty(pool)
        c = parcluster('local');
        if c.NumWorkers < numWorkers, c.NumWorkers = numWorkers; saveProfile(c); end
        parpool(c,numWorkers);
    end
    pctRunOnAll(sprintf('addpath(genpath(''%s'')); setenv(''TPIMMOEA_EXECUTION_HOST'',''%s''); setenv(''TPIMMOEA_CASA_HOSTNAME'',''%s''); setenv(''CUDA_VISIBLE_DEVICES'',''-1'');', ...
        strrep(PlatEMORoot,'''',''''''),getenv('TPIMMOEA_EXECUTION_HOST'),getenv('TPIMMOEA_CASA_HOSTNAME')));
    for b = 1 : numel(blocks)
        t0 = tic;
        m = run_ac(blocks{b},false,[],1:30,numWorkers);
        fprintf('[AC-%s] finished in %.1f min. total=%d complete-before=%d\n',blocks{b},toc(t0)/60,m.nTasks,m.nComplete);
    end
end
