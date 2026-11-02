function tasks = i_build_tasks(block)
%I_BUILD_TASKS  Phase I: sensitivity of TP-IM-MOEA (g15) to the
%population size N, which also sets the number of nodes of the map and the
%capacity 2N of the archive. Protocol of phase C (hard budget of 300
%evaluations, IGD of the nondominated solutions among all evaluations).
%The instances of the parameter sensitivity analysis: WFG2, WFG4, WFG6 and
%WFG9 x (m,d) in {(3,10),(9,100)}, 30 runs. N = 50 is block C4 (s00_default).
%
%   I1  N = 30 and N = 100                                                 480
%
%   Output: Data_I/<block>/<config>/<name>.mat.

    if ~strcmp(block,'I1'), error('Unknown block %s. Use I1.',block); end
    root  = fullfile(fileparts(mfilename('fullpath')),'Data_I',block);
    Q1    = q_build_tasks('Q1');
    g15   = Q1(1).param;
    tasks = struct('algName',{},'probName',{},'M',{},'D',{},'N',{},'maxFE',{},'run',{}, ...
                   'metName',{},'saveNum',{},'param',{},'config',{},'outFile',{},'checkArchive',{});
    for N = [30,100]
        cfg = sprintf('n%03d',N);
        for p = {'WFG2','WFG4','WFG6','WFG9'}
            for md = [3 10; 9 100]'
                for r = 1:30
                    name = sprintf('TPIMMOEA_X_%s_%s_M%d_D%d_%d',cfg,p{1},md(1),md(2),r);
                    tasks(end+1) = struct('algName','TPIMMOEA_X','probName',p{1},'M',md(1),'D',md(2),'N',N, ...
                        'maxFE',300,'run',r,'metName',{{'IGD','runtime'}},'saveNum',1,'param',{g15},'config',cfg, ...
                        'outFile',fullfile(root,cfg,[name '.mat']),'checkArchive',true); %#ok<AGROW>
                end
            end
        end
    end
    [tasks.protocol] = deal('all');
end
