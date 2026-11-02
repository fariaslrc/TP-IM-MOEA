function tasks = f_build_tasks(block)
%F_BUILD_TASKS  Phase F, protocol of phase C (hard budget of 300
%evaluations, IGD of the nondominated solutions among all evaluations).
%
%   F1  TP-IM-MOEA (g15) with shuffled anchors, instrumented: a fraction
%       anchorShuf in {0, 0.25, 0.5, 1} of the nodes have their anchors
%       permuted (a sample of region r trains node pi(r), reproduction
%       still reads node r). Every run records its final prototypes and
%       the accuracy of the prescreening on all candidates. The runs with
%       anchorShuf = 0 keep the file names of phase C (same seeds), so they
%       must reproduce the g15 runs exactly. WFG1-9 x m {3,6,9} x
%       d {10,100}, 30 runs                                              6,480
%   F2  K-RVEA with an initial design of N = 50 samples (KRVEANI), d = 10
%       only, WFG1-9 x m {3,6,9}, 30 runs                                  810
%
%   Output: Data_F/<block>/<config>/<name>.mat.

    root  = fullfile(fileparts(mfilename('fullpath')),'Data_F',block);
    WFG   = arrayfun(@(i)sprintf('WFG%d',i),1:9,'UniformOutput',false);
    tasks = struct('algName',{},'probName',{},'M',{},'D',{},'N',{},'maxFE',{},'run',{}, ...
                   'metName',{},'saveNum',{},'param',{},'config',{},'outFile',{},'checkArchive',{});
    switch block
        case 'F1'
            Q1 = q_build_tasks('Q1');
            g15 = Q1(1).param;
            g15(end+1:27) = {[]};
            cfgs = {'g15i',0; 'a025',0.25; 'a050',0.5; 'a100',1};
            for c = 1 : size(cfgs,1)
                par = [g15, {cfgs{c,2}, 1}];             % anchorShuf, instr
                lab = cfgs{c,1};
                if strcmp(lab,'g15i'), lab = 'g15'; end  % same name, hence same seed, as phase C
                for p = 1:9
                    for M = [3,6,9]
                        for D = [10,100]
                            for r = 1:30
                                name = sprintf('TPIMMOEA_X_%s_%s_M%d_D%d_%d',lab,WFG{p},M,D,r);
                                tasks(end+1) = struct('algName','TPIMMOEA_X','probName',WFG{p},'M',M,'D',D,'N',50, ...
                                    'maxFE',300,'run',r,'metName',{{'IGD','runtime'}},'saveNum',1,'param',{par}, ...
                                    'config',cfgs{c,1},'outFile',fullfile(root,cfgs{c,1},[name '.mat']), ...
                                    'checkArchive',true); %#ok<AGROW>
                            end
                        end
                    end
                end
            end
        case 'F2'
            for p = 1:9
                for M = [3,6,9]
                    for r = 1:30
                        name = sprintf('KRVEANI_KRVEA50_%s_M%d_D10_%d',WFG{p},M,r);
                        tasks(end+1) = struct('algName','KRVEANI','probName',WFG{p},'M',M,'D',10,'N',50,'maxFE',300, ...
                            'run',r,'metName',{{'IGD','runtime'}},'saveNum',1,'param',{{[],[],[],50}}, ...
                            'config','KRVEA50','outFile',fullfile(root,'KRVEA50',[name '.mat']),'checkArchive',false); %#ok<AGROW>
                    end
                end
            end
        otherwise
            error('Unknown block %s. Use F1 or F2.',block);
    end
    [tasks.protocol] = deal('all');
end
