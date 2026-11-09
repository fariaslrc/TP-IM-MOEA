function source = ac_provenance(tasks,requireRuntime)
%AC_PROVENANCE Record resolved sources, not merely the repository copy.
% File locations are reported; the digest uses logical names and bytes so
% an identical installation may be relocated from the development computer to the execution machine.
    if nargin < 2, requireRuntime = false; end
    names = {'TPIMMOEA_X','x1_options','x1_parameters','PROBLEM','ALGORITHM', ...
        'SOLUTION','UniformPoint','NDSort','OperatorGA','OperatorDE','HV','IGD', ...
        'TournamentSelection','ac_build_tasks','run_ac','run_one_ac_task', ...
        'ac_task_identity','ac_provenance','ac_sha256','ac_result_matches', ...
        'ac_check_host','ac_verify_provenance','c_build_tasks','d_build_tasks','q_build_tasks', ...
        'p3_build_tasks','s_build_tasks'};
    required = {'TPIMMOEA_X','x1_options','x1_parameters','PROBLEM','ALGORITHM','SOLUTION', ...
        'UniformPoint','NDSort','platemo','pdist2','lhsdesign'};
    if any(~cellfun(@(p)isempty(p{45}),{tasks.param}))
        required = [required,{'x1_transport','x1_history_append','x1_graph','x1_cooperation_weights', ...
            'x1_movement_fit','x1_movement_apply','x1_movement_update','x1_repair_fit','x1_repair_apply'}];
    end
    if any(contains({tasks.config},'repair') | strcmp({tasks.config},'combined'))
        required{end+1} = 'quadprog';
    end
    % NNLS is also used by the historical SOM readout.
    required{end+1} = 'lsqnonneg';
    helper = which('x1_options');
    if ~isempty(helper)
        listing = dir(fullfile(fileparts(helper),'x1_*.m'));
        for i = 1:numel(listing), [~,n] = fileparts(listing(i).name); names{end+1} = n; end %#ok<AGROW>
    end
    names = unique([names,required,unique({tasks.probName})]);
    required = unique([required,unique({tasks.probName})]);
    files = struct('name',{},'path',{},'sha256',{});
    missing = {};
    for i = 1:numel(names)
        path = which(names{i});
        digest = 'UNRESOLVED';
        if exist(path,'file') == 2
            digest = ac_sha256(path,true);
        elseif isempty(path) && ismember(names{i},required)
            missing{end+1} = names{i}; %#ok<AGROW>
        elseif ~isempty(path)
            digest = ac_sha256(path); % MATLAB built-in descriptor, if present
        end
        files(end+1) = struct('name',names{i},'path',path,'sha256',digest); %#ok<AGROW>
    end
    logical = rmfield(files,'path');
    products = ver;
    versions = repmat(struct('name','','version',''),1,numel(products));
    for i = 1:numel(products)
        versions(i) = struct('name',products(i).Name,'version',products(i).Version);
    end
    environment = struct('matlabVersion',version,'release',version('-release'), ...
        'computer',computer,'toolboxes',versions);
    fingerprint = struct('files',logical,'environment',environment);
    source = struct('digest',ac_sha256(jsonencode(fingerprint)),'files',files, ...
        'missing',{missing},'ready',isempty(missing),'matlabVersion',version, ...
        'release',version('-release'),'computer',computer,'toolboxes',products,'environment',environment);
    if requireRuntime && ~source.ready
        error('AC:Installation','Install the full PlatEMO overlay. Missing: %s.',strjoin(missing,', '));
    end
    if requireRuntime
        core = fileread(which('PROBLEM'));
        assert(contains(core,'capFE') && contains(core,'recObjs') && contains(core,'recCons'), ...
            'AC:ProblemOverlay','Resolved PROBLEM.m does not contain the budget/recording overlay.');
        algorithm = fileread(which('TPIMMOEA_X'));
        assert(contains(algorithm,'x1_options'), ...
            'AC:AlgorithmOverlay','Resolved TPIMMOEA_X.m lacks the phase AC extension.');
        % Catch a stale installed algorithm when invoking a newer overlay runner.
        local = fullfile(fileparts(mfilename('fullpath')),'Algorithms', ...
            'Multi-objective optimization','TPIMMOEA_X','TPIMMOEA_X.m');
        if exist(local,'file') == 2
            assert(strcmp(ac_sha256(local,true),ac_sha256(which('TPIMMOEA_X'),true)), ...
                'AC:ShadowedAlgorithm','TPIMMOEA_X resolves to a different source than this runner overlay.');
        end
    end
end
