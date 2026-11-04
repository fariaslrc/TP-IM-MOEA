function T = export_ac(block,profiles,runs,outputFile,normalizationFile)
%EXPORT_AC Export every planned run, including missing/invalid identities.
% Primary RWMOP HV uses the frozen ideal/nadir file. RWMOP28 or any problem
% with no fixed reference is NaN (undefined), never zero. Zero HV is reserved
% for a defined reference and an empty feasible final population.
% Requires the matching PlatEMO overlay on the MATLAB path; performs no FEs.
    if nargin < 1 || isempty(block), block = 'AC_A'; end
    if nargin < 2, profiles = []; end
    if nargin < 3, runs = []; end
    repo = fileparts(fileparts(mfilename('fullpath')));
    if nargin < 4 || isempty(outputFile), outputFile = fullfile(repo,'results',['ac_',upper(char(block)),'.csv']); end
    if nargin < 5 || isempty(normalizationFile), normalizationFile = fullfile(repo,'results','rwmop_norm.csv'); end
    tasks = ac_build_tasks(block,profiles,runs);
    source = ac_provenance(tasks,false);
    normalizationHash = '';
    normTable = table();
    if exist(normalizationFile,'file') == 2
        normTable = readtable(normalizationFile,'TextType','string');
        normalizationHash = ac_sha256(normalizationFile,true);
    end
    row = struct('block','','profile','','problem','','M',0,'D',0,'N',0,'maxFE',0, ...
        'run',0,'seed',0,'protocol','','status','','reason','','IGDall',NaN, ...
        'IGDplusAll',NaN,'IGDreported',NaN,'HVreported',NaN,'HVfixed',NaN, ...
        'HVdefined',false,'firstFeasibleFE',NaN,'firstFeasibleCensored',NaN, ...
        'everFeasible',NaN,'finalFeasible',NaN,'nFinalFeasible',NaN, ...
        'minFinalCV',NaN,'minEvaluatedCV',NaN,'nFeasibleEvaluations',NaN, ...
        'tSolve',NaN,'runtime',NaN,'taskHash','','sourceDigest','','normalizationHash','');
    rows = repmat(row,numel(tasks),1);
    for i = 1:numel(tasks)
        t = tasks(i); r = row;
        r.block=t.block; r.profile=t.config; r.problem=t.probName; r.M=t.M; r.D=t.D;
        r.N=t.N; r.maxFE=t.maxFE; r.run=t.run; r.seed=t.seed; r.protocol=t.protocol;
        r.sourceDigest=source.digest; r.taskHash=ac_task_identity(t,source.digest);
        r.normalizationHash=normalizationHash;
        [ok,why] = ac_result_matches(t.outFile,t,source.digest);
        r.status='INVALID'; r.reason=why;
        if strcmp(why,'missing'), r.status='MISSING'; end
        if ok
            s = load(t.outFile,'metric','finalObjs','finalCons');
            r.status='COMPLETE'; r.reason='';
            metrics = {'IGDall','IGDplusAll','IGDreported','HVreported','firstFeasibleFE', ...
                'everFeasible','finalFeasible','nFinalFeasible','minFinalCV','minEvaluatedCV', ...
                'nFeasibleEvaluations','tSolve','runtime'};
            for k = 1:numel(metrics)
                if isfield(s.metric,metrics{k}), r.(metrics{k})=double(s.metric.(metrics{k})); end
            end
            r.firstFeasibleCensored = isnan(r.firstFeasibleFE);
            if strcmp(t.protocol,'popN')
                [r.HVfixed,r.HVdefined] = fixedHV(s.finalObjs,s.finalCons,t.probName,t.M,normTable);
            end
        end
        rows(i) = r;
    end
    T = struct2table(rows);
    folder = fileparts(outputFile); if ~isempty(folder) && ~exist(folder,'dir'), mkdir(folder); end
    writetable(T,outputFile);
    fprintf('Exported %d expected runs (%d complete); missing/invalid rows retained: %s\n', ...
        height(T),sum(strcmp(T.status,'COMPLETE')),outputFile);
end

function [value,defined] = fixedHV(F,C,problem,M,normTable)
    value=NaN; defined=false;
    if isempty(normTable), return; end
    idx=find(strcmp(normTable.prob,problem));
    if numel(idx) ~= 1, return; end
    lo=sscanf(char(normTable.ideal(idx)),'%f').';
    hi=sscanf(char(normTable.nadir(idx)),'%f').';
    if numel(lo) ~= M || numel(hi) ~= M || any(~isfinite([lo,hi])) || any(hi < lo), return; end
    defined=true;
    feasible=all(isfinite(C) & C <= 0,2) & all(isfinite(F),2);
    F=F(feasible,:);
    if isempty(F), value=0; return; end
    F=F(NDSort(F,1) == 1,:);
    Fn=(F-lo)./max(hi-lo,1e-12);
    state=rng; cleanup=onCleanup(@()rng(state)); %#ok<NASGU>
    rng(1,'twister');
    % HV.m otherwise adapts fmin to each population when Fn has negatives.
    % Translate to a nonnegative frame, precompensate its 1.1 multiplier,
    % then undo its volume scale. This retains the SAME physical reference
    % r=1.1 and the SAME denominator prod(r) even below the frozen ideal.
    r=1.1*ones(1,M); origin=min(min(Fn,[],1),zeros(1,M));
    shifted=Fn-origin;
    value=HV(SOLUTION(zeros(size(Fn,1),1),shifted,zeros(size(Fn,1),1)), ...
        (r-origin)/1.1)*prod((r-origin)./r);
    assert(isfinite(value) && value >= 0,'AC:HV','Invalid fixed-reference HV for %s.',problem);
end
