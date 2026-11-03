function verify_aa_results(blocks)
%VERIFY_AA_RESULTS  Final audit of Data_A/ (verify_c_results of phase C with
%the task list of phase AA; runs that stop with an error count as below budget): every expected file must exist, record the
%requested N and the protocol, never exceed the budget, and hold a finite
%score (IGDall). Runs that stopped before the budget are counted, not failed.
%
%   verify_aa_results           % block AA1
%

    here = fileparts(mfilename('fullpath'));
    addpath(genpath(here));
    if nargin < 1 || isempty(blocks), blocks = {'AA1'}; end
    if ischar(blocks), blocks = {blocks}; end
    allOK = true;
    for b = 1:numel(blocks)
        tasks = aa_build_tasks(blocks{b});
        cfgs  = unique({tasks.config});
        for c = 1:numel(cfgs)
            sub = tasks(strcmp({tasks.config},cfgs{c}));
            nMissing = 0; nShort = 0; bad = {};
            for k = 1:numel(sub)
                t = sub(k);
                if exist(t.outFile,'file') ~= 2
                    nMissing = nMissing + 1; continue;
                end
                try
                    S = load(t.outFile,'cfg','metric');
                    if strcmp(t.protocol,'all')
                        v = S.metric.IGDall;
                    else
                        v = S.metric.HV; v = v(~isnan(v));
                    end
                    ok = S.cfg.N == t.N && strcmp(S.cfg.protocol,t.protocol) && ...
                         S.cfg.nRecorded <= t.maxFE && all(isfinite(v));
                    nShort = nShort + (S.cfg.nRecorded < t.maxFE);
                catch
                    ok = false;
                end
                if ~ok, bad{end+1} = t.outFile; end %#ok<AGROW>
            end
            status = 'OK';
            if nMissing > 0 || ~isempty(bad)
                status = 'FAILED'; allOK = false;
            end
            fprintf('%s %-22s %d/%d files, %d missing, %d with problems, %d below budget  %s\n',blocks{b},cfgs{c}, ...
                numel(sub)-nMissing,numel(sub),nMissing,numel(bad),nShort,status);
            for k = 1:numel(bad), fprintf('   %s\n',bad{k}); end
        end
    end
    if allOK
        fprintf('\nAll blocks complete and consistent.\n');
    else
        fprintf('\nIncomplete or inconsistent. Rerun run_aa (it resumes), then verify again.\n');
    end
end
