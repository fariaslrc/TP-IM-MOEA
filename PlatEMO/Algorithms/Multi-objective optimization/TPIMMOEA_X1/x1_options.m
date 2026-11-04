function opt = x1_options(profile)
%X1_OPTIONS Frozen, inspectable settings for the phase AC hypotheses.
% No benchmark identity is inspected. Empty parameter 45 keeps historical
% TPIMMOEA_X unchanged; 'identity' exercises the extension without changes.
    opt = struct('version',1,'profile','identity','transport',false, ...
        'graphMode','legacy','graphK',4,'graphShuffled',false, ...
        'massBudget',-1,'supportMode','legacy','supportWeights',false, ...
        'supportPrior',2,'readMode','graph','learnCap',300, ...
        'moveMode','none','moveRadius',0.1,'moveMinRadius',0.005, ...
        'moveMaxRadius',0.25,'moveDE',0.25,'moveNeighbors',5,'moveTheta',5, ...
        'movePairRadius',0.25,'moveMinPairs',2,'moveMinGain',1e-8, ...
        'moveSupportPrior',2,'moveGrow',1.2,'moveShrink',0.7, ...
        'repairMode','none','repairRadius',0.5,'repairTolerance',0.1, ...
        'repairMinSamples',0,'repairPenalty',100,'repairMargin',1, ...
        'repairMaxCondition',1e8,'repairNumericalMargin',1e-8, ...
        'moveMinFE',300,'repairTrigger','infeasible','repairPeriod',10, ...
        'repairFeasTarget',0);
    % Activation gates (version 1, set before any phase AC result):
    %   moveMinFE        the movement field is fitted and applied only once Problem.FE >= moveMinFE,
    %                    so with a budget of 300 evaluations (expensive regime) it never acts and the
    %                    run is identical to the same profile without movement.
    %   repairTrigger    'always'     every generation;
    %                    'infeasible' only while the feasible fraction of the archive is <= repairFeasTarget
    %                                 (0: no feasible member), i.e. a feasibility-restoration phase;
    %                    'periodic'   every repairPeriod generations, if any violation has been observed;
    %                    'both'       'infeasible' or 'periodic'.
    %                    No mode acts on a problem without an observed violation (unconstrained problems).
    if nargin == 0 || isempty(profile), profile = 'cooperative'; end
    if isstruct(profile)
        assert(isscalar(profile),'X1:Options','Options must be a scalar struct.');
        names = fieldnames(profile);
        for i = 1:numel(names)
            assert(isfield(opt,names{i}),'X1:Options','Unknown option: %s',names{i});
            opt.(names{i}) = profile.(names{i});
        end
    else
        profile = char(profile);
        opt.profile = profile;
        switch profile
            case {'identity','legacy','g15'}
            case 'transport', opt.transport = true;
            case 'direct', opt.supportMode = 'direct';
            case 'mass', opt.massBudget = 1;
            case 'sparse', opt.graphMode = 'mutual';
            otherwise
                valid = {'cooperative','cooperative_no_order','cooperative_shuffled', ...
                    'cooperative_proximity','move_node','move_global','move_som', ...
                    'move_proximity','move_shrink','repair_global','repair_proximity', ...
                    'repair_som','combined'};
                assert(ismember(profile,valid),'X1:Options','Unknown profile: %s',profile);
                opt.transport = true; opt.graphMode = 'mutual';
                opt.massBudget = 1; opt.supportMode = 'direct'; opt.supportWeights = true;
                if strcmp(profile,'cooperative_shuffled'), opt.graphShuffled = true; end
                if strcmp(profile,'cooperative_proximity'), opt.readMode = 'proximity'; end
                if startsWith(profile,'move_'), opt.moveMode = extractAfter(profile,'move_'); end
                if startsWith(profile,'repair_'), opt.repairMode = extractAfter(profile,'repair_'); end
                if strcmp(profile,'combined'), opt.moveMode = 'som'; opt.repairMode = 'som'; end
        end
    end
    assert(opt.version == 1,'X1:Options','Unsupported options version.');
    assert(ismember(opt.graphMode,{'legacy','mutual'}) && ...
        ismember(opt.supportMode,{'legacy','direct'}) && ...
        ismember(opt.readMode,{'graph','proximity'}),'X1:Options','Invalid cooperation mode.');
    assert(ismember(opt.moveMode,{'none','node','global','som','proximity','shrink'}), ...
        'X1:Options','Invalid movement mode.');
    assert(ismember(opt.repairMode,{'none','global','proximity','som'}),'X1:Options','Invalid repair mode.');
    validateattributes(opt.graphK,{'numeric'},{'scalar','integer','positive','finite'});
    validateattributes(opt.massBudget,{'numeric'},{'scalar','finite','>=',-1});
    validateattributes(opt.supportPrior,{'numeric'},{'scalar','positive','finite'});
    validateattributes(opt.learnCap,{'numeric'},{'scalar','integer','positive','finite'});
    validateattributes(opt.moveDE,{'numeric'},{'scalar','>=',0,'<=',1,'finite'});
    validateattributes(opt.moveMinFE,{'numeric'},{'scalar','>=',0});
    assert(ismember(opt.repairTrigger,{'always','infeasible','periodic','both'}), ...
        'X1:Options','Invalid repair trigger.');
    validateattributes(opt.repairPeriod,{'numeric'},{'scalar','integer','positive','finite'});
    validateattributes(opt.repairFeasTarget,{'numeric'},{'scalar','>=',0,'<',1});
end
