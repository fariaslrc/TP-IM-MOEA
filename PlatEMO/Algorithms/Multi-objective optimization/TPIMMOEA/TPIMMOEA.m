classdef TPIMMOEA < TPIMMOEA_X
% <2026> <multi/many> <real/integer> <constrained/none> <expensive>
% Topology-preserving inverse-modeling multiobjective evolutionary algorithm
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
% modeling in multiobjective evolutionary optimization. Under review.
%--------------------------------------------------------------------------

% This class runs the research implementation TPIMMOEA_X with the final
% configuration of the article: a SOM anchored to a simplex of reference
% directions (BMU by angle, winner-only updates) and trained on the
% nondominated archive members, isolation-guided reconstruction refined by
% budget-adaptive DE, kNN prescreening ranked by PBI with one candidate per
% niche first, SPEA2-style truncation for M <= 3 and reference-direction
% niching for M >= 4, Latin hypercube initialization, and rejection of
% duplicate candidates. With the same random stream, its runs are identical
% to those of TPIMMOEA_X with this configuration.

    methods
        function main(Algorithm,Problem)
            [eta0,B0,F0,CR0,K,k,theta,Theta,outN] = Algorithm.ParameterSet(0.2,10,0.5,0.9,5,3,5,1000,0);
            %          numNodes eta0 sigma0 batch F  CR  kernel lattice gen sel pre preModel cheap topo ...
            config = { [],      eta0, 1,     B0,  F0, CR0, 1,     0,      1,  1,  K,  2,       1,    2, ...
                       1, 1, 1, 1, 1, 0.3, 1, 0, 0, k, theta, Theta, outN, 0, 0, 0};
            %          refMap niche infillD selRef shufFrac sigEnd refTrain lcb poolCtrl knnK pbiTheta Theta outN
            %          anchorShuf instr selMode
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
