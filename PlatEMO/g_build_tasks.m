function tasks = g_build_tasks(block)
%G_BUILD_TASKS  Phase G, protocol of phase C (hard budget of 300
%evaluations, IGD of the nondominated solutions among all evaluations).
%
%   G1  Controls of the prescreening of TP-IM-MOEA (g15): the B evaluated
%       candidates are drawn from the same pool of K*B candidates uniformly
%       at random (r1) or at random with one candidate per region of origin
%       first (r2), without any prediction. WFG1-9 x m {3,6,9} x d {10,100},
%       30 runs                                                          3,240
%   G2  Topology of the map on the held-out DTLZ suite: g15 instrumented with
%       the correct anchors (g15i, file names of phase D, hence the same
%       seeds) and with all anchors permuted (a100). DTLZ1-4, DTLZ7 x
%       m {3,6,9} x d {10,100}, 30 runs                                  1,800
%   G3  The runs that stop with an error: CSEA in D2 (DTLZ4, m = 3, d = 100,
%       runs 9 and 14) and K-RVEA with N = 50 in F2 (WFG9, m = 9, d = 10,
%       run 8), same seeds, scored on the evaluations made before the error  3
%
%   Output: Data_G/<block>/<config>/<name>.mat.

    root  = fullfile(fileparts(mfilename('fullpath')),'Data_G',block);
    Q1    = q_build_tasks('Q1');
    g15   = Q1(1).param;
    g15(end+1:27) = {[]};
    tasks = struct('algName',{},'probName',{},'M',{},'D',{},'N',{},'maxFE',{},'run',{},'metName',{}, ...
                   'saveNum',{},'param',{},'config',{},'outFile',{},'checkArchive',{},'crashTolerant',{});

    function add(prob,M,D,cfg,lab,par)
        for r = 1:30
            name = sprintf('TPIMMOEA_X_%s_%s_M%d_D%d_%d',lab,prob,M,D,r);
            tasks(end+1) = struct('algName','TPIMMOEA_X','probName',prob,'M',M,'D',D,'N',50,'maxFE',300, ...
                'run',r,'metName',{{'IGD','runtime'}},'saveNum',1,'param',{par},'config',cfg, ...
                'outFile',fullfile(root,cfg,[name '.mat']),'checkArchive',true,'crashTolerant',false);
        end
    end

    switch block
        case 'G1'
            for c = {'r1',1; 'r2',2}'
                for p = 1:9
                    for M = [3,6,9]
                        for D = [10,100]
                            add(sprintf('WFG%d',p),M,D,c{1},c{1},[g15, {0, 0, c{2}}]);   % anchorShuf, instr, selMode
                        end
                    end
                end
            end
        case 'G2'
            for c = {'g15i','g15',0; 'a100','a100',1}'
                for p = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ7'}
                    for M = [3,6,9]
                        for D = [10,100]
                            add(p{1},M,D,c{1},c{2},[g15, {c{3}, 1, 0}]);
                        end
                    end
                end
            end
        case 'G3'
            D2 = d_build_tasks('D2'); F2 = f_build_tasks('F2');
            t  = [D2(strcmp({D2.algName},'CSEA') & strcmp({D2.probName},'DTLZ4') & [D2.M] == 3 & [D2.D] == 100 & ismember([D2.run],[9 14])), ...
                  F2(strcmp({F2.probName},'WFG9') & [F2.M] == 9 & [F2.run] == 8)];
            for i = 1 : numel(t)
                [~,name] = fileparts(t(i).outFile);
                s = t(i);
                s.outFile = fullfile(root,s.config,[name '.mat']);
                s.crashTolerant = true;
                s = rmfield(s,'protocol');
                tasks(end+1) = s; %#ok<AGROW>
            end
        otherwise
            error('Unknown block %s. Use G1, G2 or G3.',block);
    end
    [tasks.protocol] = deal('all');
end
