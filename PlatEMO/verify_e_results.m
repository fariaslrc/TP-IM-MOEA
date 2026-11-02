function verify_e_results()
%VERIFY_E_RESULTS  Audit of phase E: E1 needs all 90 files (HV = NaN, no
%feasible solution, is accepted); E2 needs at least 2 of its 4 runs (runs
%that stopped with an error leave no file). Every file must record N, the
%protocol and at most maxFE evaluations.

    here = fileparts(mfilename('fullpath'));
    addpath(genpath(here));
    need  = struct('E1',90,'E2',2);
    allOK = true;
    for b = {'E1','E2'}
        tasks = e_build_tasks(b{1});
        nOK = 0; bad = {};
        for k = 1:numel(tasks)
            t = tasks(k);
            if exist(t.outFile,'file') ~= 2, continue; end
            try
                S = load(t.outFile,'cfg','metric');
                if strcmp(t.protocol,'all'), v = S.metric.IGDall; else, v = S.metric.HV; v = v(~isnan(v)); end
                ok = S.cfg.N == t.N && strcmp(S.cfg.protocol,t.protocol) && ...
                     S.cfg.nRecorded <= t.maxFE && all(isfinite(v));
            catch
                ok = false;
            end
            if ok, nOK = nOK + 1; else, bad{end+1} = t.outFile; end %#ok<AGROW>
        end
        status = 'OK';
        if nOK < need.(b{1}) || ~isempty(bad), status = 'FAILED'; allOK = false; end
        fprintf('%s %d/%d valid files (at least %d needed), %d with problems  %s\n', ...
            b{1},nOK,numel(tasks),need.(b{1}),numel(bad),status);
        for k = 1:numel(bad), fprintf('   %s\n',bad{k}); end
    end
    if allOK
        fprintf('All blocks complete and consistent.\n');
    else
        fprintf('Incomplete or inconsistent.\n');
    end
end
