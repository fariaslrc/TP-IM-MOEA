function export_te()
%EXPORT_TE  Phase TE: optimization time (metric.tSolve) and IGDall of every run of block TE1,
%written to results/c_TE1.csv.
    here = fileparts(mfilename('fullpath')); [P,ISS] = repo_paths();
    f = dir(fullfile(ISS,'Data_TE','**','*.mat'));
    fid = fopen(fullfile(fileparts(here),'results','c_TE1.csv'),'w');
    fprintf(fid,'config,file,tSolve,runtime,IGDall\n');
    for k = 1:numel(f)
        S = load(fullfile(f(k).folder,f(k).name),'metric');
        [~,cfg] = fileparts(f(k).folder);
        fprintf(fid,'%s,%s,%.6f,%.6f,%.10g\n',cfg,f(k).name,S.metric.tSolve,S.metric.runtime,S.metric.IGDall);
    end
    fclose(fid); fprintf('wrote c_TE1.csv (%d runs)\n',numel(f));
end
