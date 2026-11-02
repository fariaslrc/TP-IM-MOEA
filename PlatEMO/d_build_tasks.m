function tasks = d_build_tasks(block)
%D_BUILD_TASKS  Phase D, under the phase C protocol: hard
%budget of 300 evaluations, every evaluation recorded, and the score is the
%IGD of the nondominated solutions among all evaluations. All runs use N = 50
%and the default parameters of each algorithm; TP-IM-MOEA uses g15.
%
%   D1  Timing and cross-machine reproduction: the 16 algorithms on WFG2,
%       WFG4, WFG6 and WFG9 x (m,d) {(3,10),(9,100)}, runs 1-3, with the
%       file names (hence the seeds) of the earlier phases; K-RVEA at
%       d = 10 only. Shuffled and run with 4 workers, so that every
%       algorithm meets the same machine load                             372
%   D2  Held-out suite: DTLZ1-4 and DTLZ7 x m {3,6,9} x d {10,100}, 30 runs,
%       the WFG algorithms except REMO; K-RVEA at d = 10 only. DTLZ5 and
%       DTLZ6 are left out: for m >= 4 their Pareto fronts are not the
%       degenerate curves used as reference fronts                      13,050
%   D3  EGES on WFG1-9 x m {15,20} x d {(m-1)+10,100}, 30 runs           1,080
%   D4  REMO on the D2 grid                                                900
%   D5  EGES on the WFG grid (m {3,6,9}, d {10,100}), 30 runs, seeded and
%       capped like every other algorithm (the archived EGES runs were
%       not seeded)                                                      1,620
%
%   Output: Data_D/<block>/<config>/<name>.mat.

    root  = fullfile(fileparts(mfilename('fullpath')),'Data_D',block);
    Q1    = q_build_tasks('Q1');
    g15   = Q1(1).param;                       % parameters of the final configuration
    WFG   = arrayfun(@(i)sprintf('WFG%d',i),1:9,'UniformOutput',false);
    DTLZ  = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ7'};
    POP   = {'IMMOEAD','IMCMOEAD','SSDE','CPSMOEA','SVRNSGAII','RVEA'};
    ARCH  = {'KRVEA','MCEAD','AVGSAEA','CSEA','EGES','PIEA','ADSAPSO','SFADE'};
    tasks = newTasks();

    function add(alg,prob,M,D,runs)
        if strcmp(alg,'KRVEA') && D > 10, return; end   % 11d-1 initial samples exceed the budget
        if strcmp(alg,'TPIMMOEA_X'), cfg = 'g15'; par = g15; else, cfg = alg; par = {}; end
        for r = runs
            name = sprintf('%s_%s_%s_M%d_D%d_%d',alg,cfg,prob,M,D,r);
            tasks(end+1) = struct('algName',alg,'probName',prob,'M',M,'D',D,'N',50,'maxFE',300, ...
                'run',r,'metName',{{'IGD','runtime'}},'saveNum',1,'param',{par},'config',cfg, ...
                'outFile',fullfile(root,cfg,[name '.mat']),'checkArchive',strcmp(alg,'TPIMMOEA_X'));
        end
    end

    switch block
        case 'D1'
            for alg = [{'TPIMMOEA_X'},POP,ARCH,{'REMO'}]
                for p = {'WFG2','WFG4','WFG6','WFG9'}
                    for md = [3 10; 9 100]'
                        add(alg{1},p{1},md(1),md(2),1:3);
                    end
                end
            end
            s = RandStream('mt19937ar','Seed',2026);
            tasks = tasks(randperm(s,numel(tasks)));
        case {'D2','D4'}
            if strcmp(block,'D2'), algs = [{'TPIMMOEA_X'},POP,ARCH]; else, algs = {'REMO'}; end
            for alg = algs
                for p = DTLZ
                    for M = [3,6,9]
                        for D = [10,100]
                            add(alg{1},p{1},M,D,1:30);
                        end
                    end
                end
            end
        case 'D3'
            for p = WFG
                for M = [15,20]
                    for D = [(M-1)+10,100]
                        add('EGES',p{1},M,D,1:30);
                    end
                end
            end
        case 'D5'
            for p = WFG
                for M = [3,6,9]
                    for D = [10,100]
                        add('EGES',p{1},M,D,1:30);
                    end
                end
            end
        otherwise
            error('Unknown block %s. Use D1..D5.',block);
    end
    [tasks.protocol] = deal('all');
end

function T = newTasks()
    T = struct('algName',{},'probName',{},'M',{},'D',{},'N',{},'maxFE',{},'run',{}, ...
               'metName',{},'saveNum',{},'param',{},'config',{},'outFile',{},'checkArchive',{});
end
