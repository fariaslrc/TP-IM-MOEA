function verify_b_results(blocks)
%VERIFY_B_RESULTS  Final audit of Data_B/, driven by the task list itself:
%every expected file must exist and record the requested N, the requested
%FE and a finite IGD.
%
%   verify_b_results('B1')     % one block
%   verify_b_results           % all blocks

    here = fileparts(mfilename('fullpath'));
    addpath(genpath(here));
    if nargin < 1 || isempty(blocks), blocks = {'B1','B2','B3','B4'}; end
    if ischar(blocks), blocks = {blocks}; end
    allOK = true;
    for b = 1:numel(blocks)
        tasks = b_build_tasks(blocks{b});
        cfgs  = unique({tasks.config});
        for c = 1:numel(cfgs)
            sub = tasks(strcmp({tasks.config},cfgs{c}));
            nMissing = 0; bad = {};
            for k = 1:numel(sub)
                t = sub(k);
                if exist(t.outFile,'file') ~= 2
                    nMissing = nMissing + 1; continue;
                end
                try
                    S = load(t.outFile,'cfg','metric','result');
                    v = S.metric.(t.metName{1});
                    ok = S.cfg.N == t.N && S.result{end,1} >= t.maxFE && all(isfinite(v));
                catch
                    ok = false;
                end
                if ~ok, bad{end+1} = t.outFile; end %#ok<AGROW>
            end
            status = 'OK';
            if nMissing > 0 || ~isempty(bad)
                status = 'FAILED'; allOK = false;
            end
            fprintf('%s %-22s %d/%d files, %d missing, %d with problems  %s\n',blocks{b},cfgs{c}, ...
                numel(sub)-nMissing,numel(sub),nMissing,numel(bad),status);
            for k = 1:numel(bad), fprintf('   %s\n',bad{k}); end
        end
    end
    if allOK
        fprintf('\nAll blocks complete and consistent.\n');
    else
        fprintf('\nIncomplete or inconsistent. Rerun run_b for the block (it resumes), then verify again.\n');
    end
end
