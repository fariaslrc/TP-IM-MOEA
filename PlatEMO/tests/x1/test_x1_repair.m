function report = test_x1_repair()
%TEST_X1_REPAIR Pure synthetic-array checks; no benchmark/Problem evaluation.
%   Run with the TPIMMOEA_X1 helper folder and this folder on the MATLAB path.
%   All fixtures are deterministic and the helper calls must leave RNG state
%   untouched. quadprog is used only to solve the learned synthetic models.

    initialRng = rng;
    D = 4; n = 80;
    fixtureStream = RandStream('mt19937ar','Seed',731);
    X = rand(fixtureStream,n,D);
    G = [0 1 0;1 0 1;0 1 0];
    assoc = 1+mod((0:n-1)',3);
    A = [1,0.5,-0.2,0.3;-0.4,1,0.2,-0.1;0.2,-0.3,1,0.4];
    centre = 0.35*ones(1,D);
    b = -centre*A'-0.08;
    C = X*A'+b;
    opt = struct('repairMode','global','repairRadius',1);
    model = x1_repair_fit(X,C,assoc,G,opt);
    assert(model.global.valid,'The exact affine model should pass validation.');
    recovered = model.global.coeff.*model.global.scale;
    expected = [b;A'];
    assert(max(abs(recovered(:)-expected(:))) < 1e-10,'Affine coefficients were not recovered.');
    assert(all(model.global.validationError < 1e-10),'Unexpected affine validation error.');
    assert(model.global.nValidation >= 5 && model.global.nTrain+model.global.nValidation == n);

    % General affine coefficients use a private stream, leaving the global
    % stream untouched. This is not specific to ordering constraints.
    randomA = randn(fixtureStream,7,D);
    randomB = randn(fixtureStream,1,7);
    randomModel = x1_repair_fit(X,X*randomA'+randomB,assoc,G,opt);
    randomRecovered = randomModel.global.coeff.*randomModel.global.scale;
    randomExpected = [randomB;randomA'];
    assert(randomModel.global.valid && max(abs(randomRecovered(:)-randomExpected(:))) < 1e-10);

    candidates = [0.95,0.8,0.9,0.9;centre;0.9,0.95,0.7,0.6];
    [fixed,diag] = x1_repair_apply(candidates,[1;2;3],model,opt);
    assert(any(diag.applied),'No violated synthetic candidate was repaired.');
    trueC = fixed*A'+b;
    assert(all(trueC(:) <= 1e-7),'The exact affine repair did not reach feasibility.');
    assert(all(isfinite(fixed(:))) && all(fixed(:)>=0 & fixed(:)<=1));
    assert(isequal(fixed(2,:),centre),'A predicted-feasible candidate must stay unchanged.');

    % A separate synthetic ordering system checks zero-offset constraints,
    % without loading or evaluating any benchmark implementation.
    orderingA = [1,-1,0,0;0,1,-1,0;0,0,1,-1];
    ordering = x1_repair_fit(X,X*orderingA',assoc,G,opt);
    [ordered,orderDiag] = x1_repair_apply([0.9,0.7,0.3,0.1],1,ordering,opt);
    assert(ordering.global.valid && orderDiag.applied && all(diff(ordered) >= -1e-7));

    tiny = opt; tiny.repairRadius = 0.02;
    [small,smallDiag] = x1_repair_apply(candidates,[1;2;3],model,tiny);
    assert(max(abs(small(:)-candidates(:))) <= 0.02+1e-8);
    used = smallDiag.applied;
    assert(all(smallDiag.predCVafter(used) < smallDiag.predCVbefore(used)));

    rankDeficient = repmat(linspace(0,1,n)',1,D);
    deficient = x1_repair_fit(rankDeficient,rankDeficient*A'+b,assoc,G,opt);
    assert(~deficient.global.valid && strcmp(deficient.global.reason,'unidentifiable_training_design'));
    [unchanged,badDiag] = x1_repair_apply(candidates,[1;2;3],deficient,opt);
    assert(isequal(unchanged,candidates) && ~any(badDiag.attempted));

    nonAffine = abs(X(:,1)-0.5)-0.01;
    rejected = x1_repair_fit(X,nonAffine,assoc,G,opt);
    assert(~rejected.global.valid && strcmp(rejected.global.reason,'validation_failed'), ...
           'A global affine model spanning an absolute-value fold should be rejected.');

    % Holdout failures must be visible; fitting all observations first would
    % incorrectly reuse these changed values in the validation prediction.
    changed = C; changed(end-15:end,1) = changed(end-15:end,1)+10;
    future = x1_repair_fit(X,changed,assoc,G,opt);
    assert(~future.global.valid && strcmp(future.global.reason,'validation_failed'));

    for mode = {'som','proximity'}
        localOpt = opt; localOpt.repairMode = mode{1};
        local = x1_repair_fit(X,C,assoc,G,localOpt);
        assert(all(local.active),'Local exact affine pools should be identifiable.');
        [localFixed,localDiag] = x1_repair_apply(candidates,[1;2;3],local,localOpt);
        assert(any(localDiag.applied) && all(isfinite(localFixed(:))));
    end

    % A disconnected node with too few observations is not given invented
    % graph edges or a silent global fallback.
    disconnectedAssoc = ones(n,1); disconnectedAssoc(end) = 3;
    localOpt = opt; localOpt.repairMode = 'som';
    disconnected = x1_repair_fit(X,C,disconnectedAssoc,zeros(3),localOpt);
    assert(~disconnected.active(2) && ~disconnected.active(3));

    emptyModel = x1_repair_fit(X,zeros(n,0),assoc,G,opt);
    [noConstraints,emptyDiag] = x1_repair_apply(candidates,[1;2;3],emptyModel,opt);
    assert(isequal(noConstraints,candidates) && ~any(emptyDiag.attempted));
    zeroModel = x1_repair_fit(X,zeros(n,1),assoc,G,opt);
    [zeroConstraints,zeroDiag] = x1_repair_apply(candidates,[1;2;3],zeroModel,opt);
    assert(isequal(zeroConstraints,candidates) && ~any(zeroDiag.attempted), ...
           'An all-zero constraint column must not launch artificial QP repairs.');
    assert(isequal(rng,initialRng),'Repair helpers changed the random stream.');
    report = struct('passed',true,'checks',14,'description','Affine fitting, chronological validation, QP repair, fallback and RNG invariance');
    fprintf('test_x1_repair: all checks passed.\n');
end
