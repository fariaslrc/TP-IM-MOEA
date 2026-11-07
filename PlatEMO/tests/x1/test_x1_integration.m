function test_x1_integration()
%TEST_X1_INTEGRATION CASA-only, manually launched complete-pipeline checks.
% Configure the documented PlatEMO overlay/path first. On CASA set the two
% host variables required by ac_check_host, then call test_x1_integration.
% The host guard is the FIRST operation: this function must not start any
% algorithm locally. No benchmark suite, metric, figure or file is produced.
% These tiny synthetic runs verify contracts, not algorithm performance or
% learned-model coverage; sparse evidence is allowed to trigger fallback.

    ac_check_host();
    originalRng = rng;
    restoreRng = onCleanup(@()rng(originalRng)); %#ok<NASGU>
    profiles = {'g15','legacy','transport','direct','mass','sparse', ...
        'cooperative','cooperative_no_order','cooperative_shuffled', ...
        'cooperative_proximity','move_node','move_global','move_som', ...
        'move_proximity','move_shrink','repair_global','repair_proximity', ...
        'repair_som','combined'};
    assert(numel(profiles) == 19 && numel(unique(profiles)) == 19);
    seed = 43817;
    records = cell(size(profiles));
    for k = 1:numel(profiles)
        parameters = x1_parameters(profiles{k});
        assert(numel(parameters) == 45 && parameters{29} == 0);
        records{k} = runOne(@TPIMMOEA_X,parameters,seed);
        fprintf('test_x1_integration: profile %s passed.\n',profiles{k});
    end

    % Empty slot 45 must preserve the exact old 44-parameter recipe.
    legacyParameters = x1_parameters('legacy');
    expected44 = {[],.2,1,10,.5,.9,1,0,1,1,5,2,1,2,1,1,1,1,1,.3, ...
        1,0,0,3,5,1000,0,0,0,0,.2,0,0,0,0,0,0,0,0,0,0,1,0,0};
    assert(isequal(legacyParameters(1:44),expected44) && isempty(legacyParameters{45}), ...
        'X1Test:LegacyRecipe','The historical first 44 parameters changed.');
    old44 = runOne(@TPIMMOEA_X,legacyParameters(1:44),seed);
    legacy = records{strcmp(profiles,'legacy')};
    assertSameTrajectory(legacy,old44,'44-parameter versus empty-45 compatibility');

    identity = runOne(@TPIMMOEA_X,x1_parameters('identity'),seed);
    assertSameTrajectory(legacy,identity,'identity versus legacy');

    wrappers = {@TPIMMOEA_X1C,@TPIMMOEA_X1M,@TPIMMOEA_X1F,@TPIMMOEA_X1CMF};
    mappedProfiles = {'cooperative','move_som','repair_som','combined'};
    for k = 1:numel(wrappers)
        wrapped = runOne(wrappers{k},{0},seed);
        reference = records{strcmp(profiles,mappedProfiles{k})};
        assertSameTrajectory(reference,wrapped,func2str(wrappers{k}));
        fprintf('test_x1_integration: wrapper %s passed.\n',func2str(wrappers{k}));
    end
    fprintf(['test_x1_integration: 19 profiles, identity parity, old-44 ', ...
        'compatibility and 4 wrappers passed on CASA.\n']);
end

function record = runOne(algorithmConstructor,parameters,seed)
    rng(seed,'twister');
    problem = X1SyntheticProblem('N',12,'M',3,'D',4,'maxFE',32);
    assert(isprop(problem,'capFE') && isprop(problem,'recCons'), ...
        'X1Test:Overlay','The budget-recording PROBLEM overlay must be active.');
    problem.capFE = true;
    algorithm = algorithmConstructor('parameter',parameters,'save',1, ...
        'run',1,'metName',{},'outputFcn',@(varargin)[]);
    algorithm.Solve(problem);
    finalRng = rng;
    assert(problem.FE == 32 && problem.maxFE == 32 && ...
        problem.N == 12 && problem.M == 3 && problem.D == 4, ...
        'X1Test:Budget','Requested dimensions/population/budget were not preserved.');
    assert(isequal(size(problem.recObjs),[32,3]) && ...
        isequal(size(problem.recCons),[32,2]) && ...
        isequal(size(problem.evaluatedDecs),[32,4]), ...
        'X1Test:Records','Evaluation records have incorrect dimensions.');
    assert(problem.objectiveRows == 32 && problem.constraintRows == 32, ...
        'X1Test:HiddenEvaluations','Objective or constraint calls escaped the FE accounting.');
    assert(all(isfinite(problem.recObjs(:))) && all(isfinite(problem.recCons(:))) && ...
        all(isfinite(problem.evaluatedDecs(:))) && ...
        all(problem.evaluatedDecs(:) >= 0 & problem.evaluatedDecs(:) <= 1), ...
        'X1Test:Finite','Nonfinite values or out-of-bound decisions were recorded.');
    assert(~isempty(algorithm.result),'X1Test:Result','No population was reported.');
    reported = algorithm.result{end,2};
    decisions = reported.decs; objectives = reported.objs; constraints = reported.cons;
    assert(size(decisions,2) == 4 && size(objectives,2) == 3 && size(constraints,2) == 2 && ...
        all(isfinite(decisions(:))) && all(isfinite(objectives(:))) && ...
        all(isfinite(constraints(:))) && all(decisions(:) >= 0 & decisions(:) <= 1));
    if isfield(algorithm.metric,'x1Diagnostics')
        diagnostics = algorithm.metric.x1Diagnostics;
        for j = 1:numel(diagnostics)
            d = diagnostics{j};
            assert(d.evaluated <= d.generated && d.movementEvaluated <= d.evaluated && ...
                d.repairEvaluated <= d.evaluated && isfinite(d.radiusMean));
        end
    end
    record = struct('objs',problem.recObjs,'cons',problem.recCons, ...
        'decs',problem.evaluatedDecs,'rng',finalRng);
end

function assertSameTrajectory(left,right,label)
    assert(isequal(left.objs,right.objs) && isequal(left.cons,right.cons) && ...
        isequal(left.decs,right.decs) && isequal(left.rng,right.rng), ...
        'X1Test:Parity','Exact evaluation trajectory or final RNG differs: %s.',label);
end
