function [state,info] = x1_movement_update(state,nodes,parentF,parentC,childF,childC,RefN,opt)
%X1_MOVEMENT_UPDATE Prospective node-radius feedback from evaluated children.
% Only genuinely movement-treated, selected/evaluated candidates belong here.
% Both objective matrices MUST use the SAME frozen normalization and each
% row is compared on its recorded source reference, never its reassigned BMU.
% Feasibility is lexicographic: attaining feasibility is success; when both
% are feasible, strict regional-PBI improvement is success; when both are
% infeasible, a strict reduction of summed positive violation is success.
% A batch success fraction > 1/2 grows that node's radius by moveGrow; a
% fraction < 1/5 shrinks it by moveShrink. Other nodes/rates are unchanged.
% Accumulated trials/successes are diagnostics, not posterior probabilities.
% info: trials, successes, objectiveGain, violationGain, radiusBefore/After.

    nNodes = size(RefN,1); nodes = nodes(:); n = numel(nodes);
    validateattributes(RefN,{'numeric'},{'2d','real','finite'});
    validateattributes(nodes,{'numeric'},{'2d','real','finite','integer','>=',1,'<=',nNodes});
    assert(nNodes >= 1,'X1:MovementReference','At least one reference direction is required.');
    validateattributes(parentF,{'numeric'},{'2d','real','finite'});
    validateattributes(childF,{'numeric'},{'2d','real','finite'});
    assert(isequal(size(parentF),size(childF)) && size(parentF,1) == n && ...
        size(parentF,2) == size(RefN,2),'X1:MovementShape','Invalid parent/child objective matrices.');
    if isempty(parentC), parentC = zeros(n,0); end
    if isempty(childC), childC = zeros(n,0); end
    validateattributes(parentC,{'numeric'},{'2d','real','finite'});
    validateattributes(childC,{'numeric'},{'2d','real','finite'});
    assert(isequal(size(parentC),size(childC)) && size(parentC,1) == n, ...
        'X1:MovementShape','Invalid parent/child constraint matrices.');
    validateattributes(opt.moveMinRadius,{'numeric'},{'scalar','positive','finite'});
    validateattributes(opt.moveMaxRadius,{'numeric'},{'scalar','finite','>=',opt.moveMinRadius});
    validateattributes(opt.moveGrow,{'numeric'},{'scalar','finite','>=',1});
    validateattributes(opt.moveShrink,{'numeric'},{'scalar','finite','>',0,'<=',1});
    validateattributes(opt.moveTheta,{'numeric'},{'scalar','nonnegative','finite'});
    validateattributes(opt.moveMinGain,{'numeric'},{'scalar','nonnegative','finite'});
    if isempty(state), state = struct(); end
    if ~isfield(state,'radius'), state.radius = repmat(opt.moveRadius,nNodes,1); end
    if ~isfield(state,'trials'), state.trials = zeros(nNodes,1); end
    if ~isfield(state,'successes'), state.successes = zeros(nNodes,1); end
    assert(numel(state.radius) == nNodes && numel(state.trials) == nNodes && ...
        numel(state.successes) == nNodes,'X1:MovementShape','State must have one value per node.');
    validateattributes(state.radius,{'numeric'},{'real','positive','finite'});
    validateattributes(state.trials,{'numeric'},{'real','nonnegative','integer','finite'});
    validateattributes(state.successes,{'numeric'},{'real','nonnegative','integer','finite'});
    assert(all(state.successes(:) <= state.trials(:)), ...
        'X1:MovementState','Success counts cannot exceed trial counts.');
    state.radius = max(opt.moveMinRadius,min(opt.moveMaxRadius,state.radius(:)));
    state.trials = state.trials(:); state.successes = state.successes(:);
    info = struct('trials',zeros(nNodes,1),'successes',zeros(nNodes,1), ...
        'objectiveGain',nan(n,1),'violationGain',zeros(n,1), ...
        'radiusBefore',state.radius,'radiusAfter',state.radius);
    if n == 0, return; end
    nr = sqrt(sum(RefN.^2,2));
    assert(all(nr > 0),'X1:MovementReference','Reference directions must be nonzero.');
    RefN = RefN./nr;
    directions = RefN(nodes,:);
    pp = sum(parentF.*directions,2); cp = sum(childF.*directions,2);
    ps = pp+opt.moveTheta*sqrt(max(0,sum(parentF.^2,2)-pp.^2));
    cs = cp+opt.moveTheta*sqrt(max(0,sum(childF.^2,2)-cp.^2));
    pv = sum(max(parentC,0),2); cv = sum(max(childC,0),2);
    bothFeasible = pv <= 0 & cv <= 0;
    success = pv > 0 & cv <= 0;
    success(bothFeasible) = cs(bothFeasible) < ps(bothFeasible) - ...
        opt.moveMinGain*(1+abs(ps(bothFeasible)));
    bothInfeasible = pv > 0 & cv > 0;
    success(bothInfeasible) = cv(bothInfeasible) < pv(bothInfeasible) - ...
        opt.moveMinGain*(1+abs(pv(bothInfeasible)));
    info.objectiveGain(bothFeasible) = ps(bothFeasible)-cs(bothFeasible);
    info.violationGain = pv-cv;
    info.trials = accumarray(nodes,1,[nNodes,1]);
    info.successes = accumarray(nodes,double(success),[nNodes,1]);
    rate = info.successes./max(info.trials,1);
    grow = info.trials > 0 & rate > 0.5;
    shrink = info.trials > 0 & rate < 0.2;
    state.radius(grow) = state.radius(grow)*opt.moveGrow;
    state.radius(shrink) = state.radius(shrink)*opt.moveShrink;
    state.radius = max(opt.moveMinRadius,min(opt.moveMaxRadius,state.radius));
    state.trials = state.trials+info.trials;
    state.successes = state.successes+info.successes;
    info.radiusAfter = state.radius;
end
