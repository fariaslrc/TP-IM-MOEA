function verify_ac_campaign()
%VERIFY_AC_CAMPAIGN  Audit of phase AC (lean version 2): every block complete and valid.
    PlatEMORoot = fileparts(mfilename('fullpath'));
    addpath(genpath(PlatEMORoot)); cd(PlatEMORoot);
    allOk = true;
    for b = {'AC1','AC2','AC3','AC4'}
        s = verify_ac_results(b{1},[],1:30);
        ok = s.nComplete == s.nExpected && s.nInvalid == 0;
        fprintf('%-4s %5d/%5d complete, %d missing, %d invalid  %s\n',b{1},s.nComplete,s.nExpected,s.nMissing,s.nInvalid,okStr(ok));
        bad = s.entries(~strcmp({s.entries.status},'COMPLETE'));
        for i = 1 : min(5,numel(bad)), fprintf('     %s %s: %s\n',bad(i).status,bad(i).file,bad(i).reason); end
        allOk = allOk && ok;
    end
    if allOk, fprintf('All blocks complete and consistent.\n'); else, fprintf('AUDIT FAILED.\n'); end
end

function s = okStr(ok)
    if ok, s = 'OK'; else, s = 'FAILED'; end
end
