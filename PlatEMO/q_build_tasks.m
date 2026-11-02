function tasks = q_build_tasks(block)
%Q_BUILD_TASKS  Phase Q: full evaluation of configuration g15, the final TP-IM-MOEA:
%reference-anchored SOM (BMU by angle, one prototype per reference
%direction, trained on the non-dominated members), no lattice
%neighbourhood, kNN prescreening (K = 5) with decomposition infill,
%reference-niche selection for M >= 4, SPEA2 truncation for M <= 3, LHS,
%duplicate rejection. The baselines already exist (phase P3 and P7), so
%only g15 and its ablation are run. All WFG runs use N = 50.
%
%   Q1  WFG main grid: g15, WFG1-9 x m {3,6,9} x d {10,100}, FE 300     1,620
%   Q2  Many-objective: g15, WFG1-9 x m {15,20} x d {(m-1)+10, 100}     1,080
%   Q3  RWMOP1-35: g15 with Kumar et al. settings                       1,050
%   Q4  Ablation of g15 on the Q1 grid: without refMap, infillD, selRef,
%       prescreening, cheap; no SOM in reproduction; with lattice
%       neighbourhood; with shuffled neighbourhood          12,960
%   Q5  Figures: convergence (20 snapshots) and IGD x budget
%       (FE 150/300/600/1200), WFG3, 4, 9 x (m,d) {(3,10),(9,100)}         900
%
%   Output: Data_Q/<block>/<config>/<name>.mat

    nRuns = 30;
    root  = fullfile(fileparts(mfilename('fullpath')),'Data_Q',block);
    E     = [];
    % switches after the 6 classic parameters:
    %      kern latt gen sel pre pM cheap topo ref niche infD selR shuf sigEnd refTr
    g15 = {1,   0,   1,  1,  5,  2, 1,    2,   1,  1,    1,   1,   1,   0.3,   1};
    sig0 = 1;
    WFG  = arrayfun(@(i)sprintf('WFG%d',i),1:9,'UniformOutput',false);
    MD2  = [3,10; 9,100];
    tasks = struct('algName',{},'probName',{},'M',{},'D',{},'N',{},'maxFE',{},'run',{}, ...
                   'metName',{},'saveNum',{},'param',{},'config',{},'outFile',{},'checkArchive',{});

    function add(cfgName,sw,prob,N,M,D,FE,met,saveNum,tag)
        param = [{E,E,sig0,10,E,E}, sw];
        for r = 1:nRuns
            f = fullfile(root,cfgName,sprintf('TPIMMOEA_X_%s_%s_M%d_D%d%s_%d.mat',cfgName,prob,M,D,tag,r));
            tasks(end+1) = struct('algName','TPIMMOEA_X','probName',prob,'M',M,'D',D,'N',N,'maxFE',FE, ...
                'run',r,'metName',{{met,'runtime'}},'saveNum',saveNum,'param',{param}, ...
                'config',cfgName,'outFile',f,'checkArchive',true); %#ok<AGROW>
        end
    end
    function sw = with(idx,val)
        sw = g15; sw{idx} = val;
    end

    switch block
        case 'Q1'
            for p = 1:9, for M = [3,6,9], for D = [10,100]
                add('g15',g15,WFG{p},50,M,D,300,'IGD',1,'');
            end, end, end

        case 'Q2'
            for p = 1:9, for M = [15,20], for D = [(M-1)+10, 100]
                add('g15',g15,WFG{p},50,M,D,300,'IGD',1,'');
            end, end, end

        case 'Q3'
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
                add('g15',g15,prob,N,M,D,FE,'HV',1,'');
            end

        case 'Q4'
            abl = {
                'q01_noRefMap',      with(9,0)
                'q02_noInfillD',     with(11,0)
                'q03_noSelRef',      with(12,0)
                'q04_noPre',         with(5,0)
                'q05_noCheap',       with(7,0)
                'q06_noSOM',         with(8,3)
                'q07_withNbh',       with(8,0)
                'q08_withNbh_shuf',  with(8,1)
            };
            for a = 1:size(abl,1)
                for p = 1:9, for M = [3,6,9], for D = [10,100]
                    add(abl{a,1},abl{a,2},WFG{p},50,M,D,300,'IGD',1,'');
                end, end, end
            end

        case 'Q5'
            for p = {'WFG3','WFG4','WFG9'}
                for i = 1:size(MD2,1)
                    M = MD2(i,1); D = MD2(i,2);
                    add('conv_g15',g15,p{1},50,M,D,300,'IGD',20,'');
                    for fe = [150,300,600,1200]
                        add('budget_g15',g15,p{1},50,M,D,fe,'IGD',1,sprintf('_FE%d',fe));
                    end
                end
            end

        otherwise
            error('Unknown block %s. Use Q1..Q5.',block);
    end
end
