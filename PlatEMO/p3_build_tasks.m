function tasks = p3_build_tasks(block)
%P3_BUILD_TASKS  Task list of phase P3. The article uses the per-run data of
%blocks P3, P7 and P8 (K-RVEA, MCEA/D, AVG-SAEA and CSEA) and, through phase C,
%the output names, hence the seeds, of blocks P1, P4 and P7. Configuration
%d03 (kernel + gen + kNN prescreening (K = 5) + sel + cheap) belongs to the
%preliminary design study and is not reported in the article.
%All WFG runs use N = 50; RWMOP uses Kumar et al. N, M, D and FE.
%
%   P1  WFG main grid: d03 + IMMOEAD, IMCMOEAD, SSDE (per-run data for
%       the main table), WFG1-9 x m {3,6,9} x d {10,100}, FE 300       6,480
%   P2  Ablation of d03 on the same grid: without kernel, gen, pre, sel,
%       cheap; shuffled lattice; no neighborhood; no SOM in reproduction 12,960
%   P3  Kriging baseline with N = 50: KRVEA (d = 10 only)                 810
%   P4  Many-objective: d03, SSDE, RVEA, WFG1-9 x m {15,20} x
%       d {(m-1)+10, 100}, FE 300                                      3,240
%   P5  RWMOP1-35: d03 with Kumar et al. settings                       1,050
%   P6  Figures: convergence (20 snapshots; d03, SSDE, KRVEA (d = 10))
%       and IGD x budget for d03 (FE 150/300/600/1200),
%       WFG3, 4, 9 x (m,d) {(3,10),(9,100)}                             1,170
%
%   P7  Remaining WFG baselines with N = 50 (they all use N): MCEAD,
%       AVGSAEA, CPSMOEA, SVRNSGAII and RVEA, WFG1-9 x m {3,6,9}
%       x d {10,100}, FE 300                                           8,100
%   P8  CSEA, same grid. Needs the Deep Learning Toolbox
%       (featureInputLayer); run only where it is installed             1,620
%       EDN-ARMOEA is not included (12-20 h; kept at N = 100, declared).
%
%   EGES is not rerun: it overwrites Problem.N with min(11D-1, 100)
%   (EGES.m, line 23), so N has no effect and the archived runs remain valid.
%
%   Output: Data_P3/<block>/<config>/<name>.mat.

    nRuns = 30;
    root  = fullfile(fileparts(mfilename('fullpath')),'Data_P3',block);
    E     = [];
    d03   = {1,0,1,1,5,2,1,0};      % kernel lattice gen sel pre preModel cheap topo
    WFG   = arrayfun(@(i)sprintf('WFG%d',i),1:9,'UniformOutput',false);
    MD2   = [3,10; 9,100];
    tasks = struct('algName',{},'probName',{},'M',{},'D',{},'N',{},'maxFE',{},'run',{}, ...
                   'metName',{},'saveNum',{},'param',{},'config',{},'outFile',{},'checkArchive',{});

    function add(alg,cfgName,sw,prob,N,M,D,FE,met,saveNum,tag)
        if isempty(sw), param = {}; else, param = [{E,E,E,E,E,E}, sw]; end
        isX = strcmp(alg,'TPIMMOEA_X');
        for r = 1:nRuns
            f = fullfile(root,cfgName,sprintf('%s_%s_%s_M%d_D%d%s_%d.mat',alg,cfgName,prob,M,D,tag,r));
            tasks(end+1) = struct('algName',alg,'probName',prob,'M',M,'D',D,'N',N,'maxFE',FE, ...
                'run',r,'metName',{{met,'runtime'}},'saveNum',saveNum,'param',{param}, ...
                'config',cfgName,'outFile',f,'checkArchive',isX); %#ok<AGROW>
        end
    end

    switch block
        case 'P1'
            algs = {'TPIMMOEA_X','d03',d03; 'IMMOEAD','IMMOEAD',{}; 'IMCMOEAD','IMCMOEAD',{}; 'SSDE','SSDE',{}};
            for a = 1:size(algs,1)
                for p = 1:9
                    for M = [3,6,9]
                        for D = [10,100]
                            add(algs{a,1},algs{a,2},algs{a,3},WFG{p},50,M,D,300,'IGD',1,'');
                        end
                    end
                end
            end

        case 'P2'
            abl = {
            %   name               kernel lattice gen sel pre preModel cheap topo
                'a01_noKernel',      {0,0,1,1,5,2,1,0}
                'a02_noGen',         {1,0,0,1,5,2,1,0}
                'a03_noPre',         {1,0,1,1,0,2,1,0}
                'a04_noSel',         {1,0,1,0,5,2,1,0}
                'a05_noCheap',       {1,0,1,1,5,2,0,0}
                'a06_shuffledTopo',  {1,0,1,1,5,2,1,1}
                'a07_noNeighborhood',{1,0,1,1,5,2,1,2}
                'a08_noSOM',         {1,0,1,1,5,2,1,3}
            };
            for a = 1:size(abl,1)
                for p = 1:9
                    for M = [3,6,9]
                        for D = [10,100]
                            add('TPIMMOEA_X',abl{a,1},abl{a,2},WFG{p},50,M,D,300,'IGD',1,'');
                        end
                    end
                end
            end

        case 'P3'
            for p = 1:9
                for M = [3,6,9]
                    add('KRVEA','KRVEA',{},WFG{p},50,M,10,300,'IGD',1,'');
                end
            end

        case 'P4'
            algs = {'TPIMMOEA_X','d03',d03; 'SSDE','SSDE',{}; 'RVEA','RVEA',{}};
            for a = 1:size(algs,1)
                for p = 1:9
                    for M = [15,20]
                        for D = [(M-1)+10, 100]
                            add(algs{a,1},algs{a,2},algs{a,3},WFG{p},50,M,D,300,'IGD',1,'');
                        end
                    end
                end
            end

        case 'P5'
            rw = {
                'RWMOP1',80,2,4,20000;   'RWMOP2',80,2,5,20000;   'RWMOP3',80,2,3,20000
                'RWMOP4',80,2,4,20000;   'RWMOP5',80,2,4,20000;   'RWMOP6',80,2,7,20000
                'RWMOP7',80,2,4,20000;   'RWMOP8',105,3,7,26250;  'RWMOP9',80,2,4,20000
                'RWMOP10',80,2,2,20000;  'RWMOP11',212,5,3,53000; 'RWMOP12',80,2,4,20000
                'RWMOP13',105,3,7,26250; 'RWMOP14',80,2,5,20000;  'RWMOP15',80,2,3,20000
                'RWMOP16',80,2,2,20000;  'RWMOP17',105,3,6,26250; 'RWMOP18',80,2,3,20000
                'RWMOP19',105,3,10,26250;'RWMOP20',80,2,4,20000;  'RWMOP21',80,2,6,20000
                'RWMOP22',80,2,9,20000;  'RWMOP23',80,2,6,20000;  'RWMOP24',105,3,9,26250
                'RWMOP25',80,2,2,20000;  'RWMOP26',80,2,3,20000;  'RWMOP27',80,2,3,20000
                'RWMOP28',80,2,7,20000;  'RWMOP29',80,2,7,20000;  'RWMOP30',80,2,25,80000
                'RWMOP31',80,2,25,80000; 'RWMOP32',80,2,25,80000; 'RWMOP33',80,2,30,80000
                'RWMOP34',80,2,30,80000; 'RWMOP35',80,2,30,80000
            };
            for i = 1:size(rw,1)
                [prob,N,M,D,FE] = rw{i,:};
                add('TPIMMOEA_X','d03',d03,prob,N,M,D,FE,'HV',1,'');
            end

        case 'P6'
            for p = {'WFG3','WFG4','WFG9'}
                for i = 1:size(MD2,1)
                    M = MD2(i,1); D = MD2(i,2);
                    add('TPIMMOEA_X','conv_d03',d03,p{1},50,M,D,300,'IGD',20,'');
                    add('SSDE','conv_SSDE',{},p{1},50,M,D,300,'IGD',20,'');
                    if D == 10
                        add('KRVEA','conv_KRVEA',{},p{1},50,M,D,300,'IGD',20,'');
                    end
                    for fe = [150,300,600,1200]
                        add('TPIMMOEA_X','budget_d03',d03,p{1},50,M,D,fe,'IGD',1,sprintf('_FE%d',fe));
                    end
                end
            end

        case {'P7','P8'}
            if strcmp(block,'P7')
                algs = {'MCEAD','AVGSAEA','CPSMOEA','SVRNSGAII','RVEA'};
            else
                algs = {'CSEA'};
            end
            for alg = algs
                for p = 1:9
                    for M = [3,6,9]
                        for D = [10,100]
                            add(alg{1},alg{1},{},WFG{p},50,M,D,300,'IGD',1,'');
                        end
                    end
                end
            end

        otherwise
            error('Unknown block %s. Use P1..P8.',block);
    end
end
