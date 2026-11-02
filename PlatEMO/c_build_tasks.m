function tasks = c_build_tasks(block)
%C_BUILD_TASKS  Phase C: protocol correction. Every run has a hard budget
%(PROBLEM.capFE: no algorithm evaluates more than maxFE solutions) and
%records every evaluation. Tasks reuse the output names of the earlier
%phases, hence the same seeds, so the runs reproduce the earlier ones and
%only the scored set changes:
%   WFG    ('all')  IGD of the nondominated solutions among all evaluations
%   RWMOP  ('popN') HV of a final population of size N (TP-IM-MOEA reports
%                   N members chosen by its own environmental selection)
%
%   C1  WFG main grid, WFG1-9 x m {3,6,9} x d {10,100}, FE 300: TP-IM-MOEA
%       (g15) and the baselines that report a population: IM-MOEA/D,
%       IM-C-MOEA/D, SSDE, SVR-NSGA-II, CPS-MOEA and RVEA         11,340
%   C2  Many-objective, m {15,20}: g15, SSDE and RVEA               3,240
%   C3  Ablation of g15 (as Q4)                                    12,960
%   C4  Sensitivity: S1 and the Theta part of S2 (WFG9, FE 2000)    3,780
%   C5  RWMOP1-35 (as Q3) and the B0 part of S2, with outN = 1      1,290
%   C6  K-RVEA with initial design NI = 50 (KRVEANI), WFG main grid 1,620
%       (cancelled: its linear-trend Kriging needs at least d + 1 samples)
%   C7  Many-objective, m {15,20}: PIEA                            1,080
%   C8  RWMOP1-35 with Kumar et al. settings: IM-MOEA/D, IM-C-MOEA/D,
%       SSDE, CTAEA and RVEA, final population ('popN')            5,250
%
%   Output: Data_C/<block>/<config>/<name>.mat

    root = fullfile(fileparts(mfilename('fullpath')),'Data_C',block);
    switch block
        case 'C1'
            P = [p3_build_tasks('P1'), p3_build_tasks('P7')];
            T = [q_build_tasks('Q1'), P(ismember({P.algName},{'IMMOEAD','IMCMOEAD','SSDE','SVRNSGAII','CPSMOEA','RVEA'}))];
            prot = 'all';
        case 'C2'
            P = p3_build_tasks('P4');
            T = [q_build_tasks('Q2'), P(ismember({P.algName},{'SSDE','RVEA'}))];
            prot = 'all';
        case 'C3'
            T = q_build_tasks('Q4');
            prot = 'all';
        case 'C4'
            S2 = s_build_tasks('S2');
            T  = [s_build_tasks('S1'), S2(strcmp({S2.probName},'WFG9'))];
            prot = 'all';
        case 'C5'
            S2 = s_build_tasks('S2');
            T  = [q_build_tasks('Q3'), S2(startsWith({S2.probName},'RWMOP'))];
            for i = 1 : numel(T)            % outN is the 27th parameter of TPIMMOEA_X
                p = T(i).param;
                p(end+1:26) = {[]};
                p{27} = 1;
                T(i).param = p;
            end
            prot = 'popN';
        case 'C6'
            T = struct('algName',{},'probName',{},'M',{},'D',{},'N',{},'maxFE',{},'run',{}, ...
                       'metName',{},'saveNum',{},'param',{},'config',{},'outFile',{},'checkArchive',{});
            for p = 1 : 9
                for M = [3,6,9]
                    for D = [10,100]
                        for r = 1 : 30
                            prob = sprintf('WFG%d',p);
                            T(end+1) = struct('algName','KRVEANI','probName',prob,'M',M,'D',D,'N',50,'maxFE',300, ...
                                'run',r,'metName',{{'IGD','runtime'}},'saveNum',1,'param',{{[],[],[],50}}, ...
                                'config','KRVEA50','outFile',sprintf('KRVEANI_KRVEA50_%s_M%d_D%d_%d.mat',prob,M,D,r), ...
                                'checkArchive',false); %#ok<AGROW>
                        end
                    end
                end
            end
            prot = 'all';
        case 'C7'
            T = newTasks();
            for p = 1 : 9
                for M = [15,20]
                    for D = [(M-1)+10,100]
                        T = [T,baseTasks('PIEA',sprintf('WFG%d',p),50,M,D,300,'IGD')]; %#ok<AGROW>
                    end
                end
            end
            prot = 'all';
        case 'C8'
            T  = newTasks();
            Q3 = q_build_tasks('Q3');
            Q3 = Q3([Q3.run] == 1);                % one task per problem: Kumar et al. N, M, D, FE
            for alg = {'IMMOEAD','IMCMOEAD','SSDE','CTAEA','RVEA'}
                for i = 1 : numel(Q3)
                    q = Q3(i);
                    T = [T,baseTasks(alg{1},q.probName,q.N,q.M,q.D,q.maxFE,'HV')]; %#ok<AGROW>
                end
            end
            prot = 'popN';
        otherwise
            error('Unknown block %s. Use C1..C8.',block);
    end
    % Same file name (hence the same seed) under Data_C/<block>/<config>/
    for i = 1 : numel(T)
        [~,name] = fileparts(T(i).outFile);
        T(i).outFile = fullfile(root,T(i).config,[name '.mat']);
    end
    [T.protocol] = deal(prot);
    tasks = T;
end

function T = newTasks()
    T = struct('algName',{},'probName',{},'M',{},'D',{},'N',{},'maxFE',{},'run',{}, ...
               'metName',{},'saveNum',{},'param',{},'config',{},'outFile',{},'checkArchive',{});
end

function T = baseTasks(alg,prob,N,M,D,FE,met)
%30 runs of a baseline with default parameters, named as in phase P3
    T = newTasks();
    for r = 1 : 30
        T(end+1) = struct('algName',alg,'probName',prob,'M',M,'D',D,'N',N,'maxFE',FE, ...
            'run',r,'metName',{{met,'runtime'}},'saveNum',1,'param',{{}},'config',alg, ...
            'outFile',sprintf('%s_%s_%s_M%d_D%d_%d.mat',alg,alg,prob,M,D,r),'checkArchive',false); %#ok<AGROW>
    end
end
