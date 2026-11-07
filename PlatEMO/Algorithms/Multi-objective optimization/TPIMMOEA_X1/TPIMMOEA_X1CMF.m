classdef TPIMMOEA_X1CMF < TPIMMOEA_X
% <2026> <multi/many> <real> <constrained/none> <expensive>
% Experimental combination; do not select it before mechanism-level tests.
% outN --- 0 --- Report N solutions instead of the search archive of 2N
    methods
        function main(Algorithm,Problem)
            outN = Algorithm.ParameterSet(0);
            original = Algorithm.parameter;
            Algorithm.parameter = x1_parameters('combined',outN);
            try
                main@TPIMMOEA_X(Algorithm,Problem);
            catch err
                Algorithm.parameter = original; rethrow(err);
            end
            Algorithm.parameter = original;
        end
    end
end
