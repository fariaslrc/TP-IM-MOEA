function export_c(blocks)
%EXPORT_C  Export the phase C runs (Data_C/<block>/<config>/*.mat) to
%results/c_<block>.csv, one row per run, without rerunning anything:
%   IGDold  IGD of the reported set, as scored before phase C (reproduction check)
%   IGDall  IGD of the nondominated solutions among all evaluations (protocol 'all')
%   IGDpall IGD+ of the same solutions
%   IGD50   IGD of 50 of them chosen by the environmental selection of NSGA-III,
%           as in rescore_wfg.m (all of them if 50 or fewer)
%   HV      HV of the reported population (protocol 'popN')
%The value of IGDall recomputed here from recObjs is checked against the one
%stored by the run.
%
%   export_c                 % every block found in Data_C
%   export_c({'C1','C2'})

    here = fileparts(mfilename('fullpath'));
    [P,ISS] = repo_paths();             % PlatEMO, and the folder that holds the Data_<phase> folders
    addpath(genpath(P));
    nsga3 = fullfile(P,'Algorithms','Multi-objective optimization','NSGA-III');
    addpath(nsga3);                         % its EnvironmentalSelection first
    DC = fullfile(ISS,'Data_C');                % Data_D for the blocks of phase D
    if nargin < 1
        d = dir(fullfile(DC,'C*')); blocks = {d([d.isdir]).name};
    end
    if ischar(blocks), blocks = {blocks}; end
    if isempty(gcp('nocreate')), parpool; end
    pctRunOnAll(sprintf('addpath(genpath(''%s'')); addpath(''%s''); warning(''off'',''all'');', ...
                strrep(P,'''',''''''),strrep(nsga3,'''','''''')));

    for b = 1 : numel(blocks)
        DC = fullfile(ISS,['Data_' blocks{b}(1)]);
        f = dir(fullfile(DC,blocks{b},'**','*.mat'));
        f = f(~startsWith({f.folder},fullfile(DC,blocks{b},'_')));
        n = numel(f);
        files = fullfile({f.folder},{f.name});
        cfgName = regexprep({f.folder},'.*[\\/]','');   % fileparts would drop the decimals of s01_eta0=0.1

        % Reference fronts of the WFG and DTLZ problems, by problem and m
        keys = {};
        for k = 1 : n
            tok = regexp(f(k).name,'((?:WFG|DTLZ)\d)_M(\d+)_','tokens','once');
            if ~isempty(tok), keys{end+1} = [tok{1} '_' tok{2}]; end %#ok<AGROW>
        end
        keys = unique(keys);
        OPT  = containers.Map();
        for k = 1 : numel(keys)
            tok = regexp(keys{k},'((?:WFG|DTLZ)\d)_(\d+)','tokens','once');
            Pro = feval(tok{1},'M',str2double(tok{2}));
            OPT(keys{k}) = Pro.optimum;
        end
        opt = cell(1,n);
        for k = 1 : n
            tok = regexp(f(k).name,'((?:WFG|DTLZ)\d)_M(\d+)_','tokens','once');
            if ~isempty(tok), opt{k} = OPT([tok{1} '_' tok{2}]); end
        end

        num = nan(n,16); txt = cell(n,4);
        parfor k = 1 : n
            row = nan(1,16); tx = {'','','',''};
            try
                S = load(files{k});
                c = S.cfg;
                tx = {c.algName,c.probName,c.protocol,''};
                row(1:8) = [c.M,c.D,c.run,c.N,c.maxFE,c.nRecorded,c.capCut,c.archiveSize];
                if isfield(S.metric,'IGD'), row(9)  = S.metric.IGD(end); end
                if isfield(S.metric,'HV'),  row(10) = S.metric.HV(end);  end
                row(11) = S.metric.runtime; row(16) = c.seed;
                if isfield(S.metric,'tSolve'), row(11) = S.metric.tSolve; end   % phase D: optimization time only
                if strcmp(c.protocol,'all')
                    F  = double(S.recObjs);
                    F  = F(NDSort(F,1) == 1,:);
                    O  = opt{k};
                    igd = mean(min(pdist2(O,F),[],2));
                    if abs(igd - S.metric.IGDall) > 1e-6*max(1,igd)
                        tx{4} = sprintf('IGDall mismatch %.6g vs %.6g',igd,S.metric.IGDall);
                    end
                    dp = inf(size(O,1),1);
                    for j = 1 : size(F,1)
                        dp = min(dp,sqrt(sum(max(F(j,:) - O,0).^2,2)));
                    end
                    if size(F,1) > 50
                        rng(1,'twister');
                        Z   = UniformPoint(50,size(F,2));
                        Pop = SOLUTION(zeros(size(F,1),1),F,zeros(size(F,1),1));
                        Sel = EnvironmentalSelection(Pop,50,Z,min(F,[],1));
                        F50 = Sel.objs;
                    else
                        F50 = F;
                    end
                    % IGDall: the value computed by the run in double precision. recObjs is
                    % stored in single precision, which merges near-ties (e.g. on DTLZ4)
                    row(12:15) = [size(F,1),S.metric.IGDall,mean(dp),mean(min(pdist2(O,F50),[],2))];
                end
            catch err
                tx{4} = ['FAILED: ' err.message];
            end
            num(k,:) = row; txt(k,:) = tx;
        end

        out = fullfile(fileparts(here),'results',sprintf('c_%s.csv',blocks{b}));
        fid = fopen(out,'w');
        fprintf(fid,'block,config,alg,prob,M,D,run,N,maxFE,nRecorded,capCut,nRep,IGDold,HV,runtime,nND,IGDall,IGDpall,IGD50,seed,protocol,note\n');
        for k = 1 : n
            fprintf(fid,'%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%.10g,%.10g,%.10g,%d,%.10g,%.10g,%.10g,%d,%s,%s\n', ...
                blocks{b},cfgName{k},txt{k,1},txt{k,2},num(k,:),txt{k,3},txt{k,4});
        end
        fclose(fid);
        fprintf('%s: %d runs, %d failed, %d IGDall mismatches -> %s\n',blocks{b},n, ...
            sum(startsWith(txt(:,4),'FAILED')),sum(startsWith(txt(:,4),'IGDall')),out);
    end
end
