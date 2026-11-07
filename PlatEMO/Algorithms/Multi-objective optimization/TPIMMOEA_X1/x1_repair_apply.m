function [U,diagnostic] = x1_repair_apply(U,nodes,model,opt)
%X1_REPAIR_APPLY Repair normalized candidates using learned constraints only.
%   Solves a convex QP with squared displacement, L1 violation slacks, bounds
%   and a trust box around the unrepaired candidate. No true function is
%   called. Feasibility must subsequently be checked by the actual charged
%   Problem.Evaluation. A failed/inadequate model or failed QP leaves the
%   candidate unchanged. Programming/installation errors are not swallowed.
%
%   diagnostic contains n-by-1 attempted/applied, exitflag, step, predicted
%   CV before/after (scaled, INCLUDING the empirical margin), slack and reason.
%   No random number is drawn. Requires Optimization Toolbox only when a
%   validated model actually needs to repair a candidate.

    if nargin < 4 || isempty(opt), opt = model.options; end
    opt = defaults(opt,model.options);
    validateattributes(U,{'numeric'},{'real','2d','finite'},mfilename,'U');
    if size(U,2) ~= model.dimension
        error('x1:repair:CandidateDimension','Candidate dimension differs from the fitted model.');
    end
    if any(U(:) < -1e-10 | U(:) > 1+1e-10)
        error('x1:repair:CandidateDomain','Candidates must be normalized to [0,1].');
    end
    nodes = nodes(:); n = size(U,1);
    if numel(nodes) ~= n || any(~isfinite(nodes) | nodes < 1 | nodes > model.nNodes | nodes ~= fix(nodes))
        error('x1:repair:CandidateNodes','One valid source node is required per candidate.');
    end
    diagnostic = struct('attempted',false(n,1),'applied',false(n,1), ...
                        'exitflag',nan(n,1),'step',zeros(n,1), ...
                        'predCVbefore',nan(n,1),'predCVafter',nan(n,1), ...
                        'slack',nan(n,1),'reason',{repmat({'disabled'},n,1)});
    if strcmp(model.mode,'none') || model.nCons == 0 || n == 0
        return;
    end
    D = model.dimension; L = model.nCons;
    H = blkdiag(speye(D),sparse(L,L));
    penalty = opt.repairPenalty*ones(L,1);
    qpOptions = [];
    for i = 1:n
        if strcmp(model.mode,'global')
            item = model.global;
        else
            item = model.local{nodes(i)};
        end
        if ~item.valid
            diagnostic.reason{i} = item.reason;
            continue;
        end
        u = U(i,:);
        before = [1,u]*item.coeff + item.margin;
        beforeCV = sum(max(before,0));
        diagnostic.predCVbefore(i) = beforeCV;
        diagnostic.predCVafter(i) = beforeCV;
        if beforeCV <= 1e-10
            diagnostic.reason{i} = 'predicted_feasible';
            continue;
        end
        if isempty(qpOptions)
            if exist('quadprog','file') ~= 2
                error('x1:repair:MissingQuadprog','Validated repair requires quadprog (Optimization Toolbox).');
            end
            qpOptions = optimoptions('quadprog','Display','off','Algorithm','interior-point-convex', ...
                                     'ConstraintTolerance',1e-10,'OptimalityTolerance',1e-10,'MaxIterations',200);
        end
        diagnostic.attempted(i) = true;
        A = [sparse(item.coeff(2:end,:)'),-speye(L)];
        b = -item.coeff(1,:)'-item.margin';
        lb = [max(0,u-opt.repairRadius)';zeros(L,1)];
        ub = [min(1,u+opt.repairRadius)';inf(L,1)];
        linear = [-u';penalty];
        [solution,~,flag] = quadprog(H,linear,A,b,[],[],lb,ub,[],qpOptions);
        diagnostic.exitflag(i) = flag;
        if flag <= 0 || isempty(solution) || any(~isfinite(solution))
            diagnostic.reason{i} = 'qp_failed';
            continue;
        end
        candidate = min(1,max(0,solution(1:D)'));
        after = [1,candidate]*item.coeff + item.margin;
        afterCV = sum(max(after,0));
        diagnostic.slack(i) = sum(max(solution(D+1:end),0));
        if max(abs(candidate-u)) > opt.repairRadius+1e-8
            diagnostic.reason{i} = 'trust_bound_failed';
            continue;
        end
        if afterCV > beforeCV-max(1e-10,1e-6*beforeCV)
            diagnostic.reason{i} = 'no_predicted_progress';
            continue;
        end
        U(i,:) = candidate;
        diagnostic.applied(i) = true;
        diagnostic.step(i) = norm(candidate-u);
        diagnostic.predCVafter(i) = afterCV;
        diagnostic.reason{i} = 'repaired';
    end
end

function opt = defaults(opt,fitted)
    for name = {'repairRadius','repairPenalty'}
        key = name{1};
        if ~isfield(opt,key) || isempty(opt.(key)), opt.(key) = fitted.(key); end
    end
    validateattributes(opt.repairRadius,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(opt.repairPenalty,{'numeric'},{'scalar','real','finite','positive'});
end
