function export_ac3()
%EXPORT_AC3  Phase AC (version 3): one row per run of Data_AC/<block>/<profile>/*.mat, written to
%results/c_AC.csv. WFG/DTLZ: IGDall stored by the run (double). RWMOP: HV of the final N
%members with the fixed normalization of the article, computed exactly as rescore_rwmop_y.m
%(feasible nondominated members of the final population, rwmop_norm.csv, reference 1.1,
%rng(1) for m >= 4; no normalization (RWMOP28) or no feasible member: 0), plus feasibility.
    here = fileparts(mfilename('fullpath'));
    [P,ISS] = repo_paths();       % PlatEMO, and the folder that holds the Data_<phase> folders
    addpath(genpath(P));
    N = readtable(fullfile(fileparts(here),'results','rwmop_norm.csv'),'TextType','string','Delimiter',',');
    f = dir(fullfile(ISS,'Data_AC','A*','*','*.mat'));       % blocks AC1-AC5 and AD1-AD4
    n = numel(f);
    files = fullfile({f.folder},{f.name});
    [~,prof] = cellfun(@fileparts,{f.folder},'UniformOutput',false);
    blk = regexprep({f.folder},'.*[\\/](A[CD]\d)[\\/].*','$1');
    tok = regexp({f.name},'_g15_(\w+?)_M(\d+)_D(\d+)_(\d+)\.mat$','tokens','once');
    prob = cellfun(@(t)t{1},tok,'UniformOutput',false);
    M = cellfun(@(t)str2double(t{2}),tok); D = cellfun(@(t)str2double(t{3}),tok); run = cellfun(@(t)str2double(t{4}),tok);
    lo = cell(1,n); hi = cell(1,n);
    for k = 1 : n
        r = find(N.prob == prob{k},1);
        if startsWith(prob{k},'RWMOP') && ~isempty(r)
            lo{k} = str2double(split(N.ideal(r)))'; hi{k} = str2double(split(N.nadir(r)))';
        end
    end
    igd = nan(1,n); hv = nan(1,n); ff = nan(1,n); ef = nan(1,n); fe1 = nan(1,n); ts = nan(1,n); rep = nan(1,n);
    if isempty(gcp('nocreate')), parpool; end
    pctRunOnAll(sprintf('addpath(genpath(''%s''));',strrep(P,'''','''''')));
    parfor k = 1 : n
        S = load(files{k},'metric','result');
        m = S.metric;
        igd(k) = m.IGDall; ff(k) = m.finalFeasible; ef(k) = m.everFeasible; fe1(k) = m.firstFeasibleFE; ts(k) = m.tSolve;
        if isfield(m,'x1GateLog') && ~isempty(m.x1GateLog), rep(k) = sum(m.x1GateLog(:,3)); end
        if startsWith(prob{k},'RWMOP')
            hv(k) = 0;
            B = S.result{end,2}.best.objs;
            if ~isempty(B) && ~isempty(lo{k})
                rng(1,'twister');
                rg = max(hi{k} - lo{k},1e-12);
                Fn = (B - lo{k})./rg;
                hv(k) = HV(SOLUTION(zeros(size(Fn,1),1),Fn,zeros(size(Fn,1),1)),ones(1,size(Fn,2)));
            end
        end
    end
    T = table(blk(:),prof(:),prob(:),M(:),D(:),run(:),igd(:),hv(:),ff(:),ef(:),fe1(:),ts(:),rep(:), ...
        'VariableNames',{'block','config','prob','M','D','run','IGDall','HVnorm','finalFeasible','everFeasible','firstFeasibleFE','tSolve','repairGens'});
    writetable(T,fullfile(fileparts(here),'results','c_AC.csv'));
    fprintf('wrote c_AC.csv (%d runs)\n',n);
end
