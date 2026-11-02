function tasks = s_build_tasks(block)
%S_BUILD_TASKS  Phase S: one-at-a-time (OFAT) hyperparameter sensitivity of
%the final TP-IM-MOEA (configuration g15), following the protocol of the
%manuscript's sensitivity tables. Each configuration changes one value of
%the default; 30 runs; Wilcoxon against the default.
%
%   S1  WFG2, 4, 6, 9 x (m,d) {(3,10),(9,100)}, N = 50, FE = 300, IGD:
%       s00 default; eta0 {0.1, 0.4}; F0 {0.3, 0.7}; CR0 {0.7, 0.95};
%       prescreening factor K {3, 10}; kNN neighbours {1, 5};
%       PBI theta {2, 10}; base batch size B0 {5, 20}      15 x 8 x 30 = 3,600
%   S2  Batch adaptation (only active above Theta evaluations):
%       B0 {5, 20} on RWMOP1, 8, 21, 29 (Kumar et al. settings, HV; the
%       default B0 = 10 is phase Q, block Q3)                 2 x 4 x 30 =   240
%       Theta {500, 1000, 2000} on WFG9 x (m,d) {(3,10),(9,100)} with
%       FE = 2000 (IGD)                                       3 x 2 x 30 =   180
%
%   Defaults: eta0 0.2, F0 0.5, CR0 0.9, K 5, kNN 3, PBI theta 5, B0 10,
%   Theta 1000; sigma0 1 and sigEnd 0.3 have no effect in g15 (no lattice
%   neighbourhood), so they are not varied.
%
%   Output: Data_S/<block>/<config>/<name>.mat

    nRuns = 30;
    root  = fullfile(fileparts(mfilename('fullpath')),'Data_S',block);
    E     = [];
    tasks = struct('algName',{},'probName',{},'M',{},'D',{},'N',{},'maxFE',{},'run',{}, ...
                   'metName',{},'saveNum',{},'param',{},'config',{},'outFile',{},'checkArchive',{});

    function p = g15param(eta0,B0,F,CR,K,knnK,pbiTheta,Theta)
        %        kern latt gen sel pre pM cheap topo ref niche infD selR shuf sigEnd refTr lcb pool knnK pbiTheta Theta
        sw = {1,   0,   1,  1,  K,  2, 1,    2,   1,  1,    1,   1,   1,   0.3,   1,    0,  0,   knnK, pbiTheta, Theta};
        p  = [{E,eta0,1,B0,F,CR}, sw];
    end
    function add(cfgName,param,prob,N,M,D,FE,met)
        for r = 1:nRuns
            f = fullfile(root,cfgName,sprintf('TPIMMOEA_X_%s_%s_M%d_D%d_%d.mat',cfgName,prob,M,D,r));
            tasks(end+1) = struct('algName','TPIMMOEA_X','probName',prob,'M',M,'D',D,'N',N,'maxFE',FE, ...
                'run',r,'metName',{{met,'runtime'}},'saveNum',1,'param',{param}, ...
                'config',cfgName,'outFile',f,'checkArchive',true); %#ok<AGROW>
        end
    end

    switch block
        case 'S1'
            %   name             eta0  B0  F    CR    K   kNN  PBI  Theta
            cfg = {
                's00_default',    0.2, 10, 0.5, 0.9,  5,  3,   5,   1000
                's01_eta0=0.1',   0.1, 10, 0.5, 0.9,  5,  3,   5,   1000
                's02_eta0=0.4',   0.4, 10, 0.5, 0.9,  5,  3,   5,   1000
                's03_F0=0.3',     0.2, 10, 0.3, 0.9,  5,  3,   5,   1000
                's04_F0=0.7',     0.2, 10, 0.7, 0.9,  5,  3,   5,   1000
                's05_CR0=0.7',    0.2, 10, 0.5, 0.7,  5,  3,   5,   1000
                's06_CR0=0.95',   0.2, 10, 0.5, 0.95, 5,  3,   5,   1000
                's07_K=3',        0.2, 10, 0.5, 0.9,  3,  3,   5,   1000
                's08_K=10',       0.2, 10, 0.5, 0.9,  10, 3,   5,   1000
                's09_kNN=1',      0.2, 10, 0.5, 0.9,  5,  1,   5,   1000
                's10_kNN=5',      0.2, 10, 0.5, 0.9,  5,  5,   5,   1000
                's11_PBI=2',      0.2, 10, 0.5, 0.9,  5,  3,   2,   1000
                's12_PBI=10',     0.2, 10, 0.5, 0.9,  5,  3,   10,  1000
                's13_B0=5',       0.2, 5,  0.5, 0.9,  5,  3,   5,   1000
                's14_B0=20',      0.2, 20, 0.5, 0.9,  5,  3,   5,   1000
            };
            for c = 1:size(cfg,1)
                param = g15param(cfg{c,2:end});
                for p = {'WFG2','WFG4','WFG6','WFG9'}
                    for MD = [3 10; 9 100]'
                        add(cfg{c,1},param,p{1},50,MD(1),MD(2),300,'IGD');
                    end
                end
            end

        case 'S2'
            rw = {'RWMOP1',80,2,4,20000; 'RWMOP8',105,3,7,26250; 'RWMOP21',80,2,6,20000; 'RWMOP29',80,2,7,20000};
            for B0 = [5 20]
                name = sprintf('b%02d_B0=%d',B0,B0);
                for i = 1:size(rw,1)
                    [prob,N,M,D,FE] = rw{i,:};
                    add(name,g15param(0.2,B0,0.5,0.9,5,3,5,1000),prob,N,M,D,FE,'HV');
                end
            end
            for Th = [500 1000 2000]
                name = sprintf('t%04d_Theta=%d',Th,Th);
                for MD = [3 10; 9 100]'
                    add(name,g15param(0.2,10,0.5,0.9,5,3,5,Th),'WFG9',50,MD(1),MD(2),2000,'IGD');
                end
            end

        otherwise
            error('Unknown block %s. Use S1 or S2.',block);
    end
end
