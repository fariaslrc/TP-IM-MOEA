function test_x1_movement()
%TEST_X1_MOVEMENT Pure-array tests; no benchmark, optimization or evaluation.
    opt = x1_options('move_node');
    X = [.8;.6;.4]; F = [.6,0;.4,0;.2,0]; R = [1,0];
    before = rng;
    M = x1_movement_fit(X,F,[],R,0,opt);
    assert(M.pairCount == 2 && M.vectors(1) < 0,'Improvement direction was not learned.');
    assert(all(M.pairGain > 0) && all(abs(M.pairStep) <= opt.movePairRadius+1e-12));
    S = struct('radius',.1);
    [u,di] = x1_movement_apply(.6,.64,1,M,S,opt);
    assert(di.applied && u < .6 && u >= 0 && u <= 1);
    assert(abs(u-.6) <= .1+1e-12,'Trust radius was exceeded.');

    % A single feasible sample cannot form an objective-progress pair.
    bad = x1_movement_fit(X,F,[-1;1;1],R,0,opt);
    assert(bad.pairCount == 0);
    [u,di] = x1_movement_apply(.6,.64,1,bad,S,opt);
    assert(~di.applied && isequal(u,.64),'No-support fallback changed DE.');

    % A distant solution is never linked merely because its PBI is better.
    branch = x1_movement_fit([0;.01;1],F,[],R,0,opt);
    assert(all(abs(branch.pairStep) <= opt.movePairRadius+1e-12));
    assert(~any(branch.pairSource == 3 | branch.pairTarget == 3));

    % All controls are fitted from the exact same original observations/pairs.
    X2 = [.8;.7;.6;.1;.2;.3];
    F2 = [.6,0;.4,0;.2,0;0,.6;0,.4;0,.2];
    R2 = eye(2); G = [0,1;1,0]; baseline = [];
    for mode = {'node','global','som','proximity','shrink'}
        opt.moveMode = mode{1}; mm = x1_movement_fit(X2,F2,[],R2,G,opt);
        pp = [mm.pairSource,mm.pairTarget,mm.pairOrigin,mm.pairGain];
        if isempty(baseline), baseline = pp; else, assert(isequal(pp,baseline)); end
        assert(all(isfinite(mm.vectors(:))) && all(mm.effectiveSupport <= mm.pairCount+1e-10));
        for j = 1:2
            [uu,dd] = x1_movement_apply(.5,.9,j,mm,struct('radius',[.02;.02]),opt);
            assert(isfinite(uu) && uu >= 0 && uu <= 1);
            if dd.applied, assert(abs(uu-.5) <= .02+1e-12); end
        end
    end

    opt.moveMode = 'shrink';
    noStep = x1_movement_fit(X,F,[],R,0,opt);
    [unchanged,di] = x1_movement_apply(.6,.6,1,noStep,struct('radius',.1),opt);
    assert(unchanged == .6 && ~di.applied,'An unchanged candidate received movement credit.');

    opt.moveMode = 'node';
    [S,di] = x1_movement_update([],1,[.6,0],[],[.4,0],[],R,opt);
    assert(abs(S.radius-.12) < 1e-12 && S.trials == 1 && S.successes == 1);
    assert(di.objectiveGain > 0);
    [S,~] = x1_movement_update(S,1,[.4,0],[],[.6,0],[],R,opt);
    assert(abs(S.radius-.084) < 1e-12 && S.trials == 2 && S.successes == 1);
    [~,di] = x1_movement_update([],1,[.4,0],-1,[.1,0],1,R,opt);
    assert(di.successes == 0,'Becoming infeasible was rewarded.');
    [~,di] = x1_movement_update([],1,[.4,0],1,[.9,0],-1,R,opt);
    assert(di.successes == 1,'Attaining feasibility was not rewarded.');
    [emptyState,di] = x1_movement_update([],zeros(0,1),zeros(0,2),[],zeros(0,2),[],R,opt);
    assert(emptyState.radius == opt.moveRadius && di.trials == 0);
    assert(isequal(before,rng),'Movement helpers consumed random numbers.');
    fprintf('test_x1_movement: all pure-array tests passed.\n');
end
