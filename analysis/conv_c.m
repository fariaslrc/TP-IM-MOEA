function conv_c()
%CONV_C  Convergence curves under the uniform protocol (Fig. S1): mean over
%30 runs of the IGD of the nondominated solutions among the first t
%evaluations, t = 10, 20, ..., 300, on WFG3, WFG4 and WFG9 with
%(m,d) = (3,10) and (9,100). TP-IM-MOEA and SSDE come from the recorded
%evaluations of block C1 and EGES from those of block D5 (seeded runs);
%PIEA and K-RVEA return all their evaluations in order, and their first
%300 are used. Writes conv_c.csv.

    here = fileparts(mfilename('fullpath'));
    [P,ISS] = repo_paths();             % PlatEMO, and the folder that holds the Data_<phase> folders
    addpath(genpath(P));
    src = {'OURS',  fullfile(ISS,'Data_C','C1','g15'),   'TPIMMOEA_X_g15_%s_M%d_D%d_%d.mat', 'rec'
           'SSDE',  fullfile(ISS,'Data_C','C1','SSDE'),  'SSDE_SSDE_%s_M%d_D%d_%d.mat',      'rec'
           'PIEA',  fullfile(ISS,'Data_B','B1','PIEA'),  'PIEA_PIEA_%s_M%d_D%d_%d.mat',      'arch'
           'KRVEA', fullfile(ISS,'Data_P3','P3','KRVEA'),'KRVEA_KRVEA_%s_M%d_D%d_%d.mat',    'arch'
           'EGES',  fullfile(ISS,'Data_D','D5','EGES'),  'EGES_EGES_%s_M%d_D%d_%d.mat',      'rec'};
    T = 10:10:300;
    fid = fopen(fullfile(fileparts(here),'results','conv_c.csv'),'w');
    fprintf(fid,'alg,prob,M,D,t,IGD,nRuns\n');
    for prob = {'WFG3','WFG4','WFG9'}
        for md = [3 10; 9 100]'
            M = md(1); D = md(2);
            Pro = feval(prob{1},'M',M); O = Pro.optimum;
            for s = 1 : size(src,1)
                if strcmp(src{s,1},'KRVEA') && D > 10, continue; end
                Dn = D;
                curves = [];
                for r = 1 : 30
                    f = fullfile(src{s,2},sprintf(src{s,3},prob{1},M,Dn,r));
                    if exist(f,'file') ~= 2, continue; end
                    if strcmp(src{s,4},'rec')
                        S = load(f,'recObjs'); F = double(S.recObjs);
                    else
                        S = load(f,'result'); Pop = S.result{end,2}; F = Pop(1:min(300,numel(Pop))).objs;
                    end
                    c = nan(1,numel(T));
                    for k = 1 : numel(T)
                        if T(k) > size(F,1), break; end
                        G = F(1:T(k),:); G = G(NDSort(G,1) == 1,:);
                        c(k) = mean(min(pdist2(O,G),[],2));
                    end
                    curves = [curves; c]; %#ok<AGROW>
                end
                for k = 1 : numel(T)
                    v = curves(:,k); v = v(~isnan(v));
                    if numel(v) == size(curves,1) && ~isempty(v)
                        fprintf(fid,'%s,%s,%d,%d,%d,%.10g,%d\n',src{s,1},prob{1},M,D,T(k),mean(v),numel(v));
                    end
                end
                fprintf('%s %s m%d d%d: %d runs\n',src{s,1},prob{1},M,D,size(curves,1));
            end
        end
    end
    fclose(fid);
end
