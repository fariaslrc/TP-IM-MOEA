function tasks = b_build_tasks(block)
%B_BUILD_TASKS  Phase B: four further surrogate-assisted baselines that fit
%the WFG protocol at d = 100 (initial sample of at most 109 solutions), run
%on the same grid as the other baselines of phase P3:
%WFG1-9 x m {3,6,9} x d {10,100}, N = 50, FE = 300, 30 runs, IGD.
%
%   B1  PIEA     (Information Sciences 2024)          1,620   about 0.5 h
%   B2  ADSAPSO  (Complex & Intelligent Systems 2022) 1,620   about 2 h
%   B3  SFADE    (SFA-DE, SWEVO 2024)                 1,620   about 2 h
%   B4  REMO     (IEEE TEVC 2022)                     1,620   about 21 h
%
%   All four need the Deep Learning Toolbox. SFADE rounds N to the number
%   of uniform weight vectors, as the other decomposition-based baselines
%   do; the audit checks only the requested N, as in phase P3.
%
%   Output: Data_B/<block>/<alg>/<name>.mat

    nRuns = 30;
    root  = fullfile(fileparts(mfilename('fullpath')),'Data_B',block);
    WFG   = arrayfun(@(i)sprintf('WFG%d',i),1:9,'UniformOutput',false);
    tasks = struct('algName',{},'probName',{},'M',{},'D',{},'N',{},'maxFE',{},'run',{}, ...
                   'metName',{},'saveNum',{},'param',{},'config',{},'outFile',{},'checkArchive',{});

    switch block
        case 'B1', alg = 'PIEA';
        case 'B2', alg = 'ADSAPSO';
        case 'B3', alg = 'SFADE';
        case 'B4', alg = 'REMO';
        otherwise, error('Unknown block %s. Use B1..B4.',block);
    end
    for p = 1:9
        for M = [3,6,9]
            for D = [10,100]
                for r = 1:nRuns
                    f = fullfile(root,alg,sprintf('%s_%s_%s_M%d_D%d_%d.mat',alg,alg,WFG{p},M,D,r));
                    tasks(end+1) = struct('algName',alg,'probName',WFG{p},'M',M,'D',D,'N',50,'maxFE',300, ...
                        'run',r,'metName',{{'IGD','runtime'}},'saveNum',1,'param',{{}}, ...
                        'config',alg,'outFile',f,'checkArchive',false); %#ok<AGROW>
                end
            end
        end
    end
end
