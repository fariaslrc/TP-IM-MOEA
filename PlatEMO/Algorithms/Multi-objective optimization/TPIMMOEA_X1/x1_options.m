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
        'moveMinFE',300,'repairTrigger','infeasible','repairFeasTarget',0, ...
        'orderGate',false);
    % Activation gates (version 1, set before any phase AC result):
    %   moveMinFE        the movement field is fitted and applied only once Problem.FE >= moveMinFE,
    %                    so with a budget of 300 evaluations (expensive regime) it never acts and the
    %                    run is identical to the same profile without movement.
    %   repairTrigger    'infeasible' (the only mode): repair acts only while the feasible fraction of the
    %                    archive is <= repairFeasTarget (0: no feasible member), i.e. a feasibility-restoration
    %                    phase; it never acts on a problem without an observed violation.
    %   orderGate        true: the ordering phase is skipped when the reference lattice has resolution
    %                    H1 = 1 (every direction of a layer adjacent to every other), see TPIMMOEA_X.
    % Profiles of version 3 (phase AC): 'gated' is X1 with orderGate; 'gated_transport', 'gated_mass'
    % and 'gated_direct' add one change each; 'coop3' adds the three; 'gated_repair_global' and
    % 'gated_repair_som' add the repair; 'gated_mass_repair_global' (phase AC, block AC5) is
    % gated_mass with the global repair. The legacy graph of X1 is kept in all of them.
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
            case {'gated','gated_transport','gated_mass','gated_direct','coop3', ...
                  'gated_repair_global','gated_repair_som','gated_mass_repair_global'}
                opt.orderGate = true;
                if ismember(profile,{'gated_transport','coop3'}), opt.transport = true; end
                if ismember(profile,{'gated_mass','coop3','gated_mass_repair_global'}), opt.massBudget = 1; end
                if ismember(profile,{'gated_direct','coop3'}), opt.supportMode = 'direct'; end
                if contains(profile,'repair_'), opt.repairMode = extractAfter(profile,'repair_'); end
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
    assert(strcmp(opt.repairTrigger,'infeasible'),'X1:Options','The only repair trigger is ''infeasible''.');
    assert(islogical(opt.orderGate) && isscalar(opt.orderGate),'X1:Options','orderGate must be logical.');
    validateattributes(opt.repairFeasTarget,{'numeric'},{'scalar','>=',0,'<',1});
end
