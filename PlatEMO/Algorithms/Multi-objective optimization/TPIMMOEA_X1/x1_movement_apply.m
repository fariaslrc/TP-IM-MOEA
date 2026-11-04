function [U,info] = x1_movement_apply(Base,U,node,model,state,opt)
%X1_MOVEMENT_APPLY A bounded field-guided move or matched DE-shrink control.
% Root calls this only for the predeclared subset of generated candidates.
% The RMS norm of the TOTAL normalized displacement is capped by the node's
% radius, then the box [0,1]^D is enforced. Unsupported learned moves return
% the original candidate exactly. There are no random draws or evaluations.
% info: applied, mode, node, support, radius, movementRMS, stepRMS,
%       clipped, reason. 'shrink' always applies the same cap without a field.

    validateattributes(Base,{'numeric'},{'row','real','finite','nonempty'});
    validateattributes(U,{'numeric'},{'row','real','finite','numel',numel(Base)});
    assert(all(Base >= -1e-10 & Base <= 1+1e-10) && all(U >= -1e-10 & U <= 1+1e-10), ...
        'X1:MovementBounds','Base and U must be normalized decision vectors.');
    validateattributes(node,{'numeric'},{'scalar','integer','>=',1,'<=',model.nNodes});
    assert(numel(Base) == model.D,'X1:MovementShape','Candidate dimension differs from model.');
    mode = char(opt.moveMode);
    assert(strcmp(mode,model.mode),'X1:MovementMode','Fit and apply modes must agree.');
    validateattributes(opt.moveDE,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
    validateattributes(opt.moveMinRadius,{'numeric'},{'scalar','positive','finite'});
    validateattributes(opt.moveMaxRadius,{'numeric'},{'scalar','positive','finite','>=',opt.moveMinRadius});
    if isempty(state) || ~isfield(state,'radius')
        radius = opt.moveRadius;
    else
        assert(numel(state.radius) == model.nNodes,'X1:MovementShape','Radius must have one value per node.');
        radius = state.radius(node);
    end
    validateattributes(radius,{'numeric'},{'scalar','positive','finite'});
    radius = max(opt.moveMinRadius,min(opt.moveMaxRadius,radius));
    info = struct('applied',false,'mode',mode,'node',node,'support',model.support(node), ...
        'radius',radius,'movementRMS',0,'stepRMS',sqrt(mean((U-Base).^2)), ...
        'clipped',false,'reason','disabled');
    if strcmp(mode,'none'), return; end

    original = U;
    move = zeros(size(Base));
    if ~strcmp(mode,'shrink')
        if model.confidence(node) <= 0 || model.support(node) < opt.moveMinPairs
            info.reason = 'insufficient_support'; return;
        end
        % Read-out explicitly shares the trained neighbouring vectors in SOM
        % mode. The confidence was computed from ORIGINAL pair coefficients.
        move = model.confidence(node)*(model.readWeights(node,:)*model.trainedVectors);
        if sqrt(mean(move.^2)) <= 1e-12
            info.reason = 'zero_field'; return;
        end
    end
    step = move+opt.moveDE*(U-Base);
    rms = sqrt(mean(step.^2));
    if rms > radius, step = step*(radius/rms); end
    proposed = Base+step;
    U = min(1,max(0,proposed));
    info.applied = any(U ~= original);
    info.movementRMS = sqrt(mean(move.^2));
    info.stepRMS = sqrt(mean((U-Base).^2));
    info.clipped = rms > radius || any(proposed ~= U);
    info.reason = 'applied';
    if ~info.applied, info.reason = 'unchanged'; end
end
