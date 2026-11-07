classdef TPIMMOEA < TPIMMOEA_X
% <2026> <multi/many> <real/integer> <constrained/none> <expensive>
% Topology-preserving inverse-modeling multi-objective evolutionary algorithm
% eta0  --- 0.2  --- Initial learning rate of the SOM
% B0    --- 10   --- Base batch size of real evaluations
% F0    --- 0.5  --- Base scaling factor of DE
% CR0   --- 0.9  --- Base crossover rate of DE
% K     --- 5    --- Screening factor (K*B candidates generated per generation)
% k     --- 3    --- Number of neighbors of the kNN predictor
% theta --- 5    --- Penalty of the PBI function
% Theta --- 1000 --- Evaluation budget above which the batch size is adapted
% outN  --- 0    --- 1: return N solutions chosen by the environmental selection instead of the archive of 2N

%------------------------------- Reference --------------------------------
% L. R. C. de Farias and A. F. R. Araujo. Topology-preserving inverse
% modeling in multi-objective evolutionary optimization. Under review.
%--------------------------------------------------------------------------

% This class runs the research implementation TPIMMOEA_X with the final
% configuration of the article (internal profile 'gated_repair_global'):
% a SOM anchored to a simplex of reference directions (BMU by angle) and
% trained on the nondominated archive members, with a cooperative ordering
% phase in the first 20% of the epochs of each training call (skipped when
% the outer layer of the reference lattice has resolution H1 = 1) and
% winner-only updates afterwards; isolation-guided reconstruction read on
% the cell of the parent (its node and up to m-1 lattice neighbours, convex
% weights) and refined by budget-adaptive DE; kNN prescreening ranked by PBI
% with one candidate per niche first; on constrained problems, repair with
% global affine constraint models while the archive has no feasible member;
% SPEA2-style truncation for M <= 3 and reference-direction niching for
% M >= 4; Latin hypercube initialization; rejection of duplicate candidates.
% With the same random stream, its runs are identical to those of
% TPIMMOEA_X with x1_parameters('gated_repair_global',outN).
% The previous configuration of the article (winner-only map, single-node
% read-out, no repair) is x1_parameters('g15',outN).

    methods
        function main(Algorithm,Problem)
            [eta0,B0,F0,CR0,K,k,theta,Theta,outN] = Algorithm.ParameterSet(0.2,10,0.5,0.9,5,3,5,1000,0);
            config = x1_parameters('gated_repair_global',outN);
            config{2} = eta0; config{4} = B0; config{5} = F0; config{6} = CR0;
            config{11} = K; config{24} = k; config{25} = theta; config{26} = Theta;
            user = Algorithm.parameter;
            Algorithm.parameter = config;
            try
                main@TPIMMOEA_X(Algorithm,Problem);
            catch err                       % PlatEMO ends a run by raising an error at the budget
                Algorithm.parameter = user;
                rethrow(err);
            end
            Algorithm.parameter = user;
        end
    end
end
