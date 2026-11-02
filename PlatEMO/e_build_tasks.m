function tasks = e_build_tasks(block)
%E_BUILD_TASKS  Phase E: the runs that failed in C8 and D2.
%
%   E1  IM-MOEA/D on RWMOP10, RWMOP16 and RWMOP25 (d = 2), 30 runs, the
%       C8 tasks themselves (same file names, hence the same seeds). Its
%       operator now models min(3,d) variables, as in IM-C-MOEA/D; nothing
%       changes for d >= 3                                                   90
%   E2  CSEA on DTLZ4, m = 3, d = 100: runs 9 and 14 of D2 stop with an
%       error inside CSEA for their seeds, so runs 31-34 (new seeds) are
%       run and the first two that complete replace them. Runs that stop
%       with an error are expected and leave no file                          4
%
%   Output: Data_C/C8/IMMOEAD/ (E1) and Data_D/D2/CSEA/ (E2), with the names
%   of those blocks.

    switch block
        case 'E1'
            T = c_build_tasks('C8');
            tasks = T(strcmp({T.algName},'IMMOEAD') & ismember({T.probName},{'RWMOP10','RWMOP16','RWMOP25'}));
        case 'E2'
            T = d_build_tasks('D2');
            t = T(strcmp({T.algName},'CSEA') & strcmp({T.probName},'DTLZ4') & [T.M] == 3 & [T.D] == 100 & [T.run] == 1);
            tasks = repmat(t,1,4);
            for i = 1 : 4
                r = 30 + i;
                tasks(i).run     = r;
                tasks(i).outFile = strrep(t.outFile,'_D100_1.mat',sprintf('_D100_%d.mat',r));
            end
        otherwise
            error('Unknown block %s. Use E1 or E2.',block);
    end
end
