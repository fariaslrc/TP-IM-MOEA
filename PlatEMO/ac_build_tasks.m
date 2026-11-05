function tasks = ac_build_tasks(block,profiles,runs)
%AC_BUILD_TASKS Phase AC (version 3); construction never runs a problem.
%   AC1 WFG m 3,6,9 (54)  AC2 WFG m 15,20 (36)  AC3 DTLZ m 3,6,9 (30): the three cooperation changes,
%       one at a time and together (coop3), on X1 with the ordering gate ('gated')
%   AC4 RWMOP1-35: coop3 and the repair (trigger 'infeasible'), global and through the SOM
%   AC5 RWMOP1-35: gated_mass (adopted in AC1-AC3) alone and with the global repair
%   AD1-AD3 (phase AD): final_A, final_B, final_AB, final_Brand on WFG m 3-9, WFG m 15/20, DTLZ
%   AD4: final_A, final_B, final_AB on RWMOP. Output Data_AC/AD<k>/<profile>/.
% Default runs 1:30, the seeds of every result of the article. The reference 'gated' is not run:
% it equals X1 where the lattice has resolution H1 >= 2 (phases X and AB) and X2 where H1 = 1
% (phase Y, m = 15 and 20), which the smoke test checks on run 1.
% Output filenames intentionally retain the historical g15 seed identity.
% Different profiles are separated by directories, not by seed filenames.
    if nargin < 1 || isempty(block), block = 'AC1'; end
    block = upper(char(block));
    coop = {'gated_transport','gated_mass','gated_direct','coop3'};
    switch block
        case 'AC1', defaults = coop; suites = {'C1'};   % WFG m 3,6,9 (54 instances)
        case 'AC2', defaults = coop; suites = {'C2'};   % WFG m 15,20 (36 instances)
        case 'AC3', defaults = coop; suites = {'D2'};   % DTLZ1-4,7 m 3,6,9 (30 instances)
        case 'AC4'                                      % RWMOP1-35, budgets of Kumar et al.
            defaults = {'coop3','gated_repair_global','gated_repair_som'};
            suites = {'C5'};
        case 'AC5'                                      % RWMOP1-35: the profile adopted in AC1-AC3, alone and with the repair
            defaults = {'gated_mass','gated_mass_repair_global'};
            suites = {'C5'};
        case {'AD1','AD2','AD3'}                        % phase AD: proposals A and B on WFG m 3-9, m 15/20, DTLZ
            defaults = {'final_A','final_B','final_AB','final_Brand'};
            suites = {strrep(strrep(strrep(block,'AD1','C1'),'AD2','C2'),'AD3','D2')};
        case 'AD4'                                      % phase AD on RWMOP
            defaults = {'final_A','final_B','final_AB'};
            suites = {'C5'};
        otherwise
            error('AC:Block','Unknown block %s. Use AC1 to AC5 or AD1 to AD4.',block);
    end
    if nargin < 2 || isempty(profiles), profiles = defaults; end
    if ischar(profiles) || isstring(profiles), profiles = cellstr(profiles); end
    assert(iscellstr(profiles) && numel(unique(profiles)) == numel(profiles), ...
        'AC:Profiles','Profiles must be unique names.'); %#ok<ISCLSTR>
    if nargin < 3 || isempty(runs), runs = 1:30; end      % the seeds of every result of the article
    validateattributes(runs,{'numeric'},{'vector','integer','positive','finite','nonempty'});
    assert(numel(unique(runs)) == numel(runs),'AC:Runs','Duplicate run IDs.');
    root = fullfile(fileparts(mfilename('fullpath')),'Data_AC',block);
    tasks = struct('algName',{},'probName',{},'M',{},'D',{},'N',{},'maxFE',{}, ...
        'run',{},'metName',{},'saveNum',{},'param',{},'config',{},'outFile',{}, ...
        'checkArchive',{},'protocol',{},'block',{},'seedName',{},'seed',{},'schemaVersion',{});
    for s = 1:numel(suites)
        if strcmp(suites{s},'D2'), source = d_build_tasks('D2');
        else, source = c_build_tasks(suites{s}); end
        source = source(strcmp({source.config},'g15') & [source.run] == 1);
        assert(~isempty(source),'AC:Templates','No g15 templates in %s.',suites{s});
        for i = 1:numel(source)
            a = source(i);
            [~,originalName] = fileparts(a.outFile);
            for r = reshape(runs,1,[])
                seedName = regexprep(originalName,'_1$',sprintf('_%d',r));
                assert(~strcmp(seedName,originalName) || r == 1,'AC:SeedName','Unexpected template filename.');
                seed = mod(sum(double(seedName).*(1:numel(seedName))) + 7919*r,2^31-1);
                for p = 1:numel(profiles)
                    config = profiles{p};
                    parameters = x1_parameters(config,strcmp(a.protocol,'popN'));
                    assert(numel(parameters) == 45 && parameters{29} == 0, ...
                        'AC:Budget','AC requires instr=0 and a 45-slot parameter vector.');
                    tasks(end+1) = struct('algName','TPIMMOEA_X','probName',a.probName, ...
                        'M',a.M,'D',a.D,'N',a.N,'maxFE',a.maxFE,'run',r, ...
                        'metName',{{'runtime'}},'saveNum',1,'param',{parameters}, ...
                        'config',config,'outFile',fullfile(root,config,[seedName,'.mat']), ...
                        'checkArchive',true,'protocol',a.protocol,'block',block, ...
                        'seedName',seedName,'seed',seed,'schemaVersion',1); %#ok<AGROW>
                end
            end
        end
    end
    assert(numel(unique({tasks.outFile})) == numel(tasks),'AC:DuplicateTasks','Duplicate result paths.');
end

