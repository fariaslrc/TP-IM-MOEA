classdef X1SyntheticProblem < PROBLEM
%X1SYNTHETICPROBLEM Small integration fixture, not an optimization benchmark.
% Smooth objective values and two affine constraints exercise the complete
% operator pipeline without using WFG, DTLZ, RWMOP or scientific metrics.
    properties
        evaluatedDecs = [];
        objectiveRows = 0;
        constraintRows = 0;
    end
    methods
        function Setting(obj)
            obj.M = 3; obj.D = 4;
            obj.encoding = ones(1,obj.D);
            obj.lower = zeros(1,obj.D); obj.upper = ones(1,obj.D);
        end
        function F = CalObj(obj,X)
            assert(size(X,2) == obj.D && all(isfinite(X(:))) && ...
                all(X(:) >= 0 & X(:) <= 1), ...
                'X1Test:Bounds','Evaluated decisions must be finite and within bounds.');
            obj.evaluatedDecs = [obj.evaluatedDecs;X];
            obj.objectiveRows = obj.objectiveRows+size(X,1);
            F = [sum((X-[.15,.70,.40,.20]).^2,2), ...
                 sum((X-[.75,.15,.40,.70]).^2,2), ...
                 sum((X-[.45,.45,.80,.45]).^2,2)];
        end
        function C = CalCon(obj,X)
            obj.constraintRows = obj.constraintRows+size(X,1);
            C = [X(:,1)+X(:,2)-1.1, .15-X(:,3)];
        end
        function R = GetOptimum(obj,~)
            R = zeros(0,obj.M);
        end
        function R = GetPF(~)
            R = [];
        end
        function value = CalMetric(~,~,~) %#ok<STOUT>
            error('X1Test:Metric','Integration tests must not compute scientific metrics.');
        end
    end
end
