function tasks = h_build_tasks(block)
%H_BUILD_TASKS  Phase H: sensitivity to the evaluation budget,
%protocol of phase C (hard budget, IGD of the nondominated solutions among
%all evaluations), N = 50, default parameters, TP-IM-MOEA with g15.
%WFG1-9 x (m,d) in {(3,10),(9,100)} x FE in {600,1000}, 30 runs.
%
%   H1  TP-IM-MOEA, SSDE and PIEA                                        3,240
%   H2  K-RVEA (d = 10 only)                                               540
%   H3  EGES                                                             1,080
%
%   A run that stops with an error is scored on the evaluations made before
%   it (crashTolerant, run_one_g_task), the failure policy of the article.
%   Output: Data_H/<block>/<config>/<name>.mat.

    root  = fullfile(fileparts(mfilename('fullpath')),'Data_H',block);
    Q1    = q_build_tasks('Q1');
    g15   = Q1(1).param;
    switch block
        case 'H1', algs = {'TPIMMOEA_X','SSDE','PIEA'};
        case 'H2', algs = {'KRVEA'};
        case 'H3', algs = {'EGES'};
        otherwise, error('Unknown block %s. Use H1, H2 or H3.',block);
    end
    tasks = struct('algName',{},'probName',{},'M',{},'D',{},'N',{},'maxFE',{},'run',{}, ...
                   'metName',{},'saveNum',{},'param',{},'config',{},'outFile',{},'checkArchive',{},'crashTolerant',{});
    for a = algs
        if strcmp(a{1},'TPIMMOEA_X'), cfg = 'g15'; par = g15; else, cfg = a{1}; par = {}; end
        for FE = [600,1000]
            for p = 1:9
                for md = [3 10; 9 100]'
                    M = md(1); D = md(2);
                    if strcmp(a{1},'KRVEA') && D > 10, continue; end
                    for r = 1:30
                        name = sprintf('%s_%s_WFG%d_M%d_D%d_FE%d_%d',a{1},cfg,p,M,D,FE,r);
                        tasks(end+1) = struct('algName',a{1},'probName',sprintf('WFG%d',p),'M',M,'D',D,'N',50, ...
                            'maxFE',FE,'run',r,'metName',{{'IGD','runtime'}},'saveNum',1,'param',{par}, ...
                            'config',sprintf('%s_FE%d',cfg,FE),'outFile',fullfile(root,sprintf('%s_FE%d',cfg,FE),[name '.mat']), ...
                            'checkArchive',strcmp(a{1},'TPIMMOEA_X'),'crashTolerant',true); %#ok<AGROW>
                    end
                end
            end
        end
    end
    [tasks.protocol] = deal('all');
end
