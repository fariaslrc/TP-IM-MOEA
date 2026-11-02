function rescore_wfg(outName,only)
%RESCORE_WFG  Re-score the saved WFG runs (m in {3,6,9}, d in {10,100}) under
%several protocols, without rerunning any algorithm:
%   IGDrep  IGD of the nondominated solutions of the scored set: the first
%           300 evaluations for algorithms that return all of them ('arch'),
%           the final population or archive otherwise ('pop')
%   IGDprep IGD+ of the same nondominated solutions
%   IGD50   IGD of 50 solutions chosen among them by the environmental
%           selection of NSGA-III (Das-Dennis directions, fixed seed), a
%           neutral rule for many objectives; all of them if 50 or fewer
%Writes results/<outName>.csv.

    here = fileparts(mfilename('fullpath'));
    [P,ISS] = repo_paths();             % PlatEMO, and the folder that holds the Data_<phase> folders
    addpath(genpath(P));
    nsga3 = fullfile(P,'Algorithms','Multi-objective optimization','NSGA-III');
    addpath(nsga3);                         % its EnvironmentalSelection first

    src = {'OURS',     fullfile(ISS,'Data_Q','Q1','g15'),            'pop'
           'IMMOEAD',  fullfile(ISS,'Data_P3','P1','IMMOEAD'),       'pop'
           'IMCMOEAD', fullfile(ISS,'Data_P3','P1','IMCMOEAD'),      'pop'
           'SSDE',     fullfile(ISS,'Data_P3','P1','SSDE'),          'pop'
           'CPSMOEA',  fullfile(ISS,'Data_P3','P7','CPSMOEA'),       'pop'
           'SVRNSGAII',fullfile(ISS,'Data_P3','P7','SVRNSGAII'),     'pop'
           'RVEA',     fullfile(ISS,'Data_P3','P7','RVEA'),          'pop'
           'KRVEA',    fullfile(ISS,'Data_P3','P3','KRVEA'),         'arch'
           'MCEAD',    fullfile(ISS,'Data_P3','P7','MCEAD'),         'arch'
           'AVGSAEA',  fullfile(ISS,'Data_P3','P7','AVGSAEA'),       'arch'
           'CSEA',     fullfile(ISS,'Data_P3','P8','CSEA'),          'arch'
           'EGES',     fullfile(P,'Data','EGES'),                    'arch'
           'PIEA',     fullfile(ISS,'Data_B','B1','PIEA'),           'arch'
           'ADSAPSO',  fullfile(ISS,'Data_B','B2','ADSAPSO'),        'arch'
           'SFADE',    fullfile(ISS,'Data_B','B3','SFADE'),          'arch'
           'REMO',     fullfile(ISS,'Data_B','B4','REMO'),           'arch'};

    if nargin > 1                           % e.g. rescore_wfg('rescore_remo',{'REMO'})
        src = src(ismember(src(:,1),only),:);
    end

    % File list
    L = {};
    for s = 1 : size(src,1)
        if ~exist(src{s,2},'dir'), continue; end
        f = dir(fullfile(src{s,2},'*.mat'));
        for k = 1 : numel(f)
            tok = regexp(f(k).name,'(WFG\d)_M(\d+)_D(\d+)_(\d+)\.mat$','tokens','once');
            if isempty(tok), continue; end
            M = str2double(tok{2}); D = str2double(tok{3});
            if ~ismember(M,[3 6 9]), continue; end
            if mod(D,10) == 1, D = D - 1; end          % archived EGES files use d + 1
            if ~ismember(D,[10 100]), continue; end
            L(end+1,:) = {src{s,1},fullfile(f(k).folder,f(k).name),src{s,3},tok{1},M,D,str2double(tok{4})}; %#ok<AGROW>
        end
    end
    fprintf('%d files\n',size(L,1));

    % Reference fronts (they depend on the problem and m only)
    OPT = containers.Map();
    for p = 1 : 9
        for M = [3 6 9]
            Pro = feval(sprintf('WFG%d',p),'M',M);
            OPT(sprintf('WFG%d_%d',p,M)) = Pro.optimum;
        end
    end
    opt = cellfun(@(k)OPT(k),strcat(L(:,4),'_',cellfun(@num2str,L(:,5),'UniformOutput',false)),'UniformOutput',false);

    n   = size(L,1);
    res = nan(n,6);
    if isempty(gcp('nocreate')), parpool; end
    pctRunOnAll(sprintf('addpath(genpath(''%s'')); addpath(''%s'');',strrep(P,'''',''''''),strrep(nsga3,'''','''''')));
    parfor k = 1 : n
        try
            S   = load(L{k,2},'result');
            Pop = S.result{end,2};
            if strcmp(L{k,3},'arch')
                Pop = Pop(1:min(300,numel(Pop)));
            end
            O   = opt{k};
            ND  = Pop(NDSort(Pop.objs,Pop.cons,1) == 1);
            F   = ND.objs;
            igd = mean(min(pdist2(O,F),[],2));
            dp  = inf(size(O,1),1);
            for j = 1 : size(F,1)
                dp = min(dp,sqrt(sum(max(F(j,:) - O,0).^2,2)));
            end
            if numel(ND) > 50
                rng(1,'twister');
                Z   = UniformPoint(50,size(F,2));
                Sel = EnvironmentalSelection(ND,50,Z,min(F,[],1));
                F50 = Sel.objs;
            else
                F50 = F;
            end
            res(k,:) = [numel(Pop),numel(ND),igd,mean(dp),mean(min(pdist2(O,F50),[],2)),size(F50,1)];
        catch err
            fprintf('FAILED %s: %s\n',L{k,2},err.message);
        end
    end

    fid = fopen(fullfile(fileparts(here),'results',[outName '.csv']),'w');
    fprintf(fid,'alg,prob,M,D,run,type,nScored,nND,IGDrep,IGDprep,IGD50,n50\n');
    for k = 1 : n
        fprintf(fid,'%s,%s,%d,%d,%d,%s,%d,%d,%.10g,%.10g,%.10g,%d\n',L{k,1},L{k,4},L{k,5},L{k,6},L{k,7},L{k,3},res(k,:));
    end
    fclose(fid);
    fprintf('wrote %s.csv (%d rows, %d failed)\n',outName,n,sum(isnan(res(:,1))));
end
