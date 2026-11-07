function export_xcell()
%EXPORT_XCELL  Block X1: the log of the cell read-out (metric.cellLog), averaged
%per run over the generations: residual of the convex fit, weight on the
%neighbours (1 - lambda_j) and nodes in the cell besides j, over all
%candidates (all_) and over the evaluated ones (ev_). Writes results/x_X1.csv.

    here = fileparts(mfilename('fullpath'));
    [P,ISS] = repo_paths();       % PlatEMO, and the folder that holds the Data_<phase> folders
    f = dir(fullfile(ISS,'Data_X','X1','**','*.mat'));
    n = numel(f);
    cfg = regexprep({f.folder},'.*[\\/]','');
    V = nan(n,6); prob = cell(n,1); M = zeros(n,1); D = M; run = M;
    for k = 1 : n
        S = load(fullfile(f(k).folder,f(k).name),'metric','cfg');
        V(k,:)  = mean(S.metric.cellLog(:,2:7),1,'omitnan');
        prob{k} = S.cfg.probName; M(k) = S.cfg.M; D(k) = S.cfg.D; run(k) = S.cfg.run;
    end
    names = {'resid','wNb','nCell'};
    T = table(cfg(:),prob,M,D,run,'VariableNames',{'config','prob','M','D','run'});
    T = [T, array2table(V,'VariableNames',[strcat('all_',names), strcat('ev_',names)])];
    writetable(T,fullfile(fileparts(here),'results','x_X1.csv'));
    fprintf('x_X1.csv: %d runs\n',n);
end
