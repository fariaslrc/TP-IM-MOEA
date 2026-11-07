function rescore_rwmop()
%RESCORE_RWMOP  HV of the final sets on RWMOP1-35 with one explicit
%normalization per problem, instead of the reference points stored in
%PlatEMO (the one of RWMOP27, [-0.243 0], leaves a zero range in its second
%objective). For each problem, the ideal and nadir points are those of the
%feasible nondominated solutions of the union of the final sets of every
%algorithm and run (phase C, blocks C5 and C8). The feasible nondominated
%members of each final set are normalized by them, and the HV is computed by
%PlatEMO with reference point 1.1 in every objective. A set without a
%feasible solution scores 0. Writes results/rwmop_hv.csv.

    here = fileparts(mfilename('fullpath'));
    [P,ISS] = repo_paths();       % PlatEMO, and the folder that holds the Data_<phase> folders
    addpath(genpath(P));
    f = [dir(fullfile(ISS,'Data_C','C5','**','*.mat')); dir(fullfile(ISS,'Data_C','C8','**','*.mat'))];
    n = numel(f);
    files = fullfile({f.folder},{f.name});
    cfg   = regexprep({f.folder},'.*[\\/]','');
    tok   = regexp({f.name},'(RWMOP\d+)_M\d+_D\d+_(\d+)\.mat$','tokens','once');
    prob  = cellfun(@(t)t{1},tok,'UniformOutput',false);
    run   = cellfun(@(t)str2double(t{2}),tok);

    % Feasible nondominated objectives of every final set
    best = cell(1,n);
    if isempty(gcp('nocreate')), parpool; end
    pctRunOnAll(sprintf('addpath(genpath(''%s''));',strrep(P,'''','''''')));
    parfor k = 1 : n
        S = load(files{k},'result');
        best{k} = S.result{end,2}.best.objs;
    end

    hv = zeros(1,n);
    probs = unique(prob);
    fn = fopen(fullfile(fileparts(here),'results','rwmop_norm.csv'),'w');           % normalization points, for the supplement
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
            rng(1,'twister');                        % Monte Carlo HV for m >= 4 (RWMOP11)
            Fn = (bi{k} - lo)./rg;
            h(k) = HV(SOLUTION(zeros(size(Fn,1),1),Fn,zeros(size(Fn,1),1)),ones(1,M));
        end
        hv(idx) = h;
        fprintf('%s: union of %d nondominated points, ideal %s, nadir %s\n',probs{i},size(U,1),mat2str(lo,4),mat2str(hi,4));
        fprintf(fn,'%s,%d,%s,%s\n',probs{i},size(U,1),strjoin(compose('%.10g',lo),' '),strjoin(compose('%.10g',hi),' '));
    end
    fclose(fn);

    fid = fopen(fullfile(fileparts(here),'results','rwmop_hv.csv'),'w');
    fprintf(fid,'config,prob,run,HVnorm,nBest\n');
    for k = 1 : n
        fprintf(fid,'%s,%s,%d,%.10g,%d\n',cfg{k},prob{k},run(k),hv(k),size(best{k},1));
    end
    fclose(fid);
    fprintf('wrote rwmop_hv.csv (%d runs)\n',n);
end
