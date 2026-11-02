function tasks = t_build_tasks(block)
%T_BUILD_TASKS  Phase T: use of the neighbourhood of the map in the final
%TP-IM-MOEA (g15), under the protocol of the article (hard budget of 300
%evaluations, IGD of the nondominated solutions among all evaluations,
%N = 50), on WFG1-9 x m {3,6,9} x d {10,100}, 30 runs. Every task keeps the
%output name of the g15 run of block C1, hence its seed, so each variant is
%paired run by run with the published g15 runs. All runs are instrumented
%(instr = 1, which draws no random number) to measure the topology of the map.
%
%   Factorial design, training (A) x reproduction (B); A0B0 is g15 itself:
%     A0  winner only                         B0  prototype of the winner
%     A1  neighbourhood in the first 10% of   B1  base point drawn among the winner and
%         the epochs of each training call        its 2 nearest trained lattice neighbours
%     A2  the same with 20% of the epochs     B2  second difference between the decision
%     A3  neighbourhood only in the first         prototypes of those 2 neighbours
%         20% of the search budget            B3  second difference between 2 of the 5 archive
%                                                 members nearest to the base point
%   Variants of the meeting of 26/10, on the final model:
%     R1  NeighborDE: both difference vectors from those 5 archive members
%     R2  DecisionSOM: BMU of training by the decision part of the prototypes
%     R3  DecisionSOM with the second difference of B3
%     R4  initial learning rate falling with the search progress
%   (A0B3 is NeighborDE_DualF of the meeting of 26/10.)
%
%   T1  19 variants x 54 instances x 30 runs                          30,780
%
%   Output: Data_T/T1/<config>/<name>.mat.

    if ~strcmp(block,'T1'), error('Unknown block %s. Use T1.',block); end
    root = fullfile(fileparts(mfilename('fullpath')),'Data_T',block);
    C1   = c_build_tasks('C1');
    base = C1(strcmp({C1.config},'g15'));
    %         name       nbPhase nbGlobal reproNb decBMU etaGlobal
    V = {'A0B1',      0,   0,   1, 0, 0
         'A0B2',      0,   0,   2, 0, 0
         'A0B3',      0,   0,   3, 0, 0
         'A1B0',    0.1,   0,   0, 0, 0
         'A1B1',    0.1,   0,   1, 0, 0
         'A1B2',    0.1,   0,   2, 0, 0
         'A1B3',    0.1,   0,   3, 0, 0
         'A2B0',    0.2,   0,   0, 0, 0
         'A2B1',    0.2,   0,   1, 0, 0
         'A2B2',    0.2,   0,   2, 0, 0
         'A2B3',    0.2,   0,   3, 0, 0
         'A3B0',      0, 0.2,   0, 0, 0
         'A3B1',      0, 0.2,   1, 0, 0
         'A3B2',      0, 0.2,   2, 0, 0
         'A3B3',      0, 0.2,   3, 0, 0
         'R1_NeighborDE',      0, 0, 4, 0, 0
         'R2_DecisionSOM',     0, 0, 0, 1, 0
         'R3_DecisionSOM_B3',  0, 0, 3, 1, 0
         'R4_GlobalEta',       0, 0, 0, 0, 1};
    tasks = repmat(base(1),1,0);
    for v = 1 : size(V,1)
        T = base;
        for i = 1 : numel(T)
            p = T(i).param;
            p(end+1:35) = {[]};
            p{29} = 1;                                  % instr
            p(31:35) = V(v,2:6);                        % nbPhase nbGlobal reproNb decBMU etaGlobal
            T(i).param  = p;
            T(i).config = V{v,1};
            [~,name] = fileparts(T(i).outFile);
            T(i).outFile = fullfile(root,V{v,1},[name '.mat']);
        end
        tasks = [tasks, T]; %#ok<AGROW>
    end
    % An error in a variant is a defect of the new code, not of a compared
    % algorithm: it must fail the run (no file), so the audit reports it
    [tasks.crashTolerant] = deal(false);
end
