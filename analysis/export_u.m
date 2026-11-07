function export_u()
%EXPORT_U  Block U1: the log of the base points of reproduction
%(metric.protoLog), averaged per run over the generations. Columns, over all
%candidates (all_) and over the evaluated ones (ev_): nMem, the number of ND
%members in the parent's region; alone, the fraction of parents alone in it;
%dPP, dPM and dMP, the distances prototype-parent, prototype-region mean and
%region mean-parent in the normalized decision space, divided by sqrt(d).
%Writes results/u_U1.csv.

    here = fileparts(mfilename('fullpath'));
    [P,ISS] = repo_paths();       % PlatEMO, and the folder that holds the Data_<phase> folders
    f = dir(fullfile(ISS,'Data_U','U1','**','*.mat'));
    f = f(~startsWith({f.folder},fullfile(ISS,'Data_U','U1','_')));
    n = numel(f);
    cfg = regexprep({f.folder},'.*[\\/]','');
    names = {'nMem','alone','dPP','dPM','dMP'};
    V = nan(n,10); prob = cell(n,1); M = zeros(n,1); D = M; run = M; nGen = M;
    for k = 1 : n
        S = load(fullfile(f(k).folder,f(k).name),'metric','cfg');
        L = S.metric.protoLog;
        V(k,:)  = mean(L(:,2:11),1,'omitnan');
        nGen(k) = size(L,1);
        prob{k} = S.cfg.probName; M(k) = S.cfg.M; D(k) = S.cfg.D; run(k) = S.cfg.run;
    end
    T = table(cfg(:),prob,M,D,run,nGen,'VariableNames',{'config','prob','M','D','run','nGen'});
    T = [T, array2table(V,'VariableNames',[strcat('all_',names), strcat('ev_',names)])];
    writetable(T,fullfile(fileparts(here),'results','u_U1.csv'));
    fprintf('u_U1.csv: %d runs\n',n);
end
