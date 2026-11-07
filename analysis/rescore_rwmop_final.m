function rescore_rwmop_final()
%RESCORE_RWMOP_FINAL  HV on RWMOP1-35 for the article with the final model, with one normalization
%common to every algorithm and run (review of 2026-11-06).
%
%The earlier scores (rescore_rwmop.m, rescore_rwmop_y/ab/z3.m, export_ac3.m) normalized the final
%model with ideal and nadir points computed WITHOUT its final sets. Where the final model found
%solutions better than that ideal (RWMOP30-35 above all), the normalized objectives were negative,
%and PlatEMO's HV.m then re-normalizes each population by its own minimum, so the scale and the
%reference point varied between runs. Here the ideal and nadir points of each problem are those of
%the feasible nondominated solutions of the union of ALL final sets reported in the article:
%  - the five competitors (block C8: IMMOEAD, IMCMOEAD, SSDE, CTAEA, RVEA);
%  - the final model F (block AC4, profile gated_repair_global);
%  - F with B0 = 5 and 20 (block Z3, Table S10).
%Every normalized objective is therefore >= 0, and HV.m computes the hypervolume with the same
%reference point 1.1 in every objective for every run (Monte Carlo with rng(1) for m >= 4).
%A set without a feasible solution scores 0. The feasibility of the final set is written apart.
%Writes results/rwmop_norm_final.csv and results/rwmop_hv_final.csv.

    here = fileparts(mfilename('fullpath'));
    [P,ISS] = repo_paths();       % PlatEMO, and the folder that holds the Data_<phase> folders
    addpath(genpath(P));
    f = [dir(fullfile(ISS,'Data_C','C8','**','*.mat'));
         dir(fullfile(ISS,'Data_AC','AC4','gated_repair_global','*.mat'));
         dir(fullfile(ISS,'Data_Z','Z3','**','*.mat'))];
    n = numel(f);
    files = fullfile({f.folder},{f.name});
    [~,cfg] = cellfun(@fileparts,{f.folder},'UniformOutput',false);
    cfg(strcmp(cfg,'gated_repair_global')) = {'F'};
    tok  = regexp({f.name},'(RWMOP\d+)_M\d+_D\d+_(\d+)\.mat$','tokens','once');
    prob = cellfun(@(t)t{1},tok,'UniformOutput',false);
    run  = cellfun(@(t)str2double(t{2}),tok);

    best = cell(1,n); feas = false(1,n);
    if isempty(gcp('nocreate')), parpool; end
    pctRunOnAll(sprintf('addpath(genpath(''%s''));',strrep(P,'''','''''')));
    parfor k = 1 : n
        S = load(files{k},'result');
        Pk = S.result{end,2};
        best{k} = Pk.best.objs;                              % feasible nondominated members
        feas(k) = any(all(Pk.cons <= 0,2));
    end

    hv = zeros(1,n);
    probs = unique(prob);
    fn = fopen(fullfile(fileparts(here),'results','rwmop_norm_final.csv'),'w');
    fprintf(fn,'prob,nPoints,ideal,nadir\n');
    for i = 1 : numel(probs)
        idx = find(strcmp(prob,probs{i}));
        U   = vertcat(best{idx});
        if isempty(U), continue; end
        U   = U(NDSort(U,1) == 1,:);
        lo  = min(U,[],1); hi = max(U,[],1);
        rg  = max(hi - lo,1e-12);
        M   = size(U,2);
        bi  = best(idx);
        h   = zeros(1,numel(idx));
        parfor k = 1 : numel(idx)
            if isempty(bi{k}), continue; end
            Fn = (bi{k} - lo)./rg;
            assert(all(Fn(:) >= -1e-9),'Negative normalized objective: the union does not contain this set.');
            rng(1,'twister');
            h(k) = HV(SOLUTION(zeros(size(Fn,1),1),max(Fn,0),zeros(size(Fn,1),1)),ones(1,M));
        end
        hv(idx) = h;
        fprintf(fn,'%s,%d,%s,%s\n',probs{i},size(U,1),strjoin(compose('%.10g',lo),' '),strjoin(compose('%.10g',hi),' '));
    end
    fclose(fn);

    fid = fopen(fullfile(fileparts(here),'results','rwmop_hv_final.csv'),'w');
    fprintf(fid,'config,prob,run,HVnorm,nBest,finalFeasible\n');
    for k = 1 : n
        fprintf(fid,'%s,%s,%d,%.10g,%d,%d\n',cfg{k},prob{k},run(k),hv(k),size(best{k},1),feas(k));
    end
    fclose(fid);
    fprintf('wrote rwmop_hv_final.csv (%d runs) and rwmop_norm_final.csv (%d problems)\n',n,numel(probs));
end
