function rescore_rwmop_y()
%RESCORE_RWMOP_Y  HV of the final sets of block Y2 (X2 on RWMOP1-35) with the
%normalization of the article, fixed before phase Y: the ideal and nadir points
%of rwmop_norm.csv (written by rescore_rwmop.m from blocks C5 and C8), not
%recomputed with the new runs. Same computation as rescore_rwmop.m: the
%feasible nondominated members of each final set, normalized by those points,
%HV by PlatEMO with reference point 1.1 in every objective (Monte Carlo with
%rng(1) for m >= 4); a set without a feasible solution scores 0.
%Writes results/rwmop_hv_y.csv.

    here = fileparts(mfilename('fullpath'));
    [P,ISS] = repo_paths();       % PlatEMO, and the folder that holds the Data_<phase> folders
    addpath(genpath(P));
    N = readtable(fullfile(fileparts(here),'results','rwmop_norm.csv'),'TextType','string','Delimiter',',');
    f = dir(fullfile(ISS,'Data_Y','Y2','**','*.mat'));
    n = numel(f);
    files = fullfile({f.folder},{f.name});
    tok   = regexp({f.name},'(RWMOP\d+)_M\d+_D\d+_(\d+)\.mat$','tokens','once');
    prob  = cellfun(@(t)t{1},tok,'UniformOutput',false);
    run   = cellfun(@(t)str2double(t{2}),tok);
    lo = cell(1,n); hi = cell(1,n);
    for k = 1 : n
        r = find(N.prob == prob{k},1);
        if isempty(r), continue; end        % no normalization (RWMOP28: no feasible set in the article): HV 0, as in the article
        lo{k} = str2double(split(N.ideal(r)))'; hi{k} = str2double(split(N.nadir(r)))';
    end
    hv = zeros(1,n); nb = zeros(1,n);
    if isempty(gcp('nocreate')), parpool; end
    pctRunOnAll(sprintf('addpath(genpath(''%s''));',strrep(P,'''','''''')));
    parfor k = 1 : n
        S = load(files{k},'result');
        B = S.result{end,2}.best.objs;
        nb(k) = size(B,1);
        if isempty(B) || isempty(lo{k}), continue; end
        rng(1,'twister');
        rg = max(hi{k} - lo{k},1e-12);
        Fn = (B - lo{k})./rg;
        hv(k) = HV(SOLUTION(zeros(size(Fn,1),1),Fn,zeros(size(Fn,1),1)),ones(1,size(Fn,2)));
    end
    fid = fopen(fullfile(fileparts(here),'results','rwmop_hv_y.csv'),'w');
    fprintf(fid,'config,prob,run,HVnorm,nBest\n');
    for k = 1 : n
        fprintf(fid,'X2,%s,%d,%.10g,%d\n',prob{k},run(k),hv(k),nb(k));
    end
    fclose(fid);
    fprintf('wrote rwmop_hv_y.csv (%d runs)\n',n);
end
