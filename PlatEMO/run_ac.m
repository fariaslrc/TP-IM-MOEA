function manifest = run_ac(block,dryRun,profiles,runs,numWorkers)
%RUN_AC Plan or explicitly execute one preregistered block on CASA.
%   run_ac('AC_A')                        % default: dry run only
%   run_ac('AC_A',false,[],1:10,4)         % explicit CASA pilot
%   run_ac('AC_D',false,{'g15','legacy','cooperative'},31:60,4)
% Never automatically selects a winner, starts another phase, or overwrites
% results from a different source/configuration. Do not run two controllers
% for the same task set concurrently.
    if nargin < 1 || isempty(block), block = 'AC_A'; end
    if nargin < 2 || isempty(dryRun), dryRun = true; end
    if nargin < 3, profiles = []; end
    if nargin < 4, runs = []; end
    if nargin < 5 || isempty(numWorkers), numWorkers = 1; end
    validateattributes(dryRun,{'numeric','logical'},{'scalar','binary'});
    validateattributes(numWorkers,{'numeric'},{'scalar','integer','positive','finite'});
    tasks = ac_build_tasks(block,profiles,runs);
    source = ac_provenance(tasks,~dryRun);
    ids = cell(size(tasks)); existing = false(size(tasks)); incompatible = {};
    for i = 1:numel(tasks)
        ids{i} = ac_task_identity(tasks(i),source.digest);
        if exist(tasks(i).outFile,'file') == 2
            [existing(i),why] = ac_result_matches(tasks(i).outFile,tasks(i),source.digest);
            if ~existing(i), incompatible{end+1} = sprintf('%s: %s',tasks(i).outFile,why); end %#ok<AGROW>
        end
    end
    manifest = struct('schemaVersion',1,'block',upper(char(block)),'dryRun',logical(dryRun), ...
        'createdAt',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ssXXX')), ...
        'taskSetHash',ac_sha256(strjoin(sort(ids),newline)),'source',source, ...
        'tasks',tasks,'taskHashes',{ids},'nTasks',numel(tasks),'nComplete',sum(existing), ...
        'nPending',sum(~existing),'nIncompatible',numel(incompatible),'incompatible',{incompatible}, ...
        'numWorkers',numWorkers);
    fprintf('%s: %d tasks; %d complete, %d pending, %d incompatible; %d requested workers.\n', ...
        manifest.block,manifest.nTasks,manifest.nComplete,manifest.nPending,manifest.nIncompatible,numWorkers);
    fprintf('Profiles: %s. Runs: %s. Source SHA-256: %s\n',strjoin(unique({tasks.config}),', '), ...
        mat2str(unique([tasks.run])),source.digest);
    if dryRun
        fprintf('DRY RUN: no problem construction, optimization, pool creation or result writes.\n');
        if ~source.ready, fprintf('Runtime dependencies missing: %s\n',strjoin(source.missing,', ')); end
        if ~isempty(incompatible), fprintf('Existing results require review: %s\n',incompatible{1}); end
        return;
    end
    host = ac_check_host();
    assert(isempty(incompatible),'AC:IncompatibleResume', ...
        '%d existing results differ. Use a new versioned output tree; do not overwrite or mix them.',numel(incompatible));
    pending = reshape(find(~existing),1,[]);
    if isempty(pending), fprintf('All exact task identities are already complete.\n'); return; end
    root = fileparts(fileparts(tasks(1).outFile));
    if ~exist(root,'dir'), mkdir(root); end
    manifest.host = host;
    manifestPath = fullfile(root,['manifest_',manifest.taskSetHash,'.json']);
    if exist(manifestPath,'file') ~= 2
        fid = fopen(manifestPath,'w','n','UTF-8');
        assert(fid >= 0,'AC:Manifest','Cannot open manifest %s.',manifestPath);
        cleanup = onCleanup(@()fclose(fid));
        fprintf(fid,'%s',jsonencode(manifest)); clear cleanup
    else
        previous = jsondecode(fileread(manifestPath));
        assert(strcmp(previous.taskSetHash,manifest.taskSetHash) && strcmp(previous.source.digest,source.digest), ...
            'AC:Manifest','Existing manifest does not match its filename/source identity.');
    end
    logPath = fullfile(root,['run_',datestr(now,'yyyymmdd_HHMMSS'),'_',manifest.taskSetHash(1:12),'.tsv']);
    logID = fopen(logPath,'w','n','UTF-8');
    assert(logID >= 0,'AC:Log','Cannot create run log.');
    logCleanup = onCleanup(@()fclose(logID)); %#ok<NASGU>
    fprintf(logID,'status\tseconds\tfile\tnote\n');
    pool = [];
    if numWorkers > 1
        assert(license('test','Distrib_Computing_Toolbox'),'AC:Parallel','Parallel Computing Toolbox is required.');
        pool = gcp('nocreate');
        if isempty(pool), pool = parpool('local',numWorkers); end
        assert(pool.NumWorkers == numWorkers,'AC:Pool', ...
            'Existing pool has %d workers; requested %d. Close or resize it explicitly.',pool.NumWorkers,numWorkers);
    end
    errors = 0; finished = 0;
    % Bounded batches keep the future queue small. An already open pool is
    % reused and never deleted or used to rewrite the user's cluster profile.
    for first = 1:100:numel(pending)
        batch = pending(first:min(first+99,numel(pending)));
        if numWorkers == 1
            for index = batch
                [status,elapsed,note] = run_one_ac_task(tasks(index),source);
                record(index,status,elapsed,note);
            end
        else
            futures = parallel.FevalFuture.empty(0,numel(batch));
            for j = 1:numel(batch)
                futures(j) = parfeval(pool,@run_one_ac_task,3,tasks(batch(j)),source);
            end
            futureCleanup = onCleanup(@()cancel(futures));
            for j = 1:numel(batch)
                [whichFuture,status,elapsed,note] = fetchNext(futures);
                record(batch(whichFuture),status,elapsed,note);
            end
            clear futureCleanup
        end
    end
    manifest.nErrors = errors;
    fprintf('Finished %d pending tasks with %d errors. Log: %s\n',finished,errors,logPath);

    function record(index,status,elapsed,note)
        finished = finished+1; errors = errors+strcmp(status,'ERROR');
        cleanNote = regexprep(note,'[\r\n\t]+',' ');
        fprintf(logID,'%s\t%.6f\t%s\t%s\n',status,elapsed,tasks(index).outFile,cleanNote);
        fprintf('[%d/%d] %s %s %s run=%d %.1fs %s\n',finished,numel(pending),status, ...
            tasks(index).config,tasks(index).probName,tasks(index).run,elapsed,cleanNote);
        assert(~strcmp(status,'ERROR'),'AC:TaskFailure', ...
            'Campaign stopped after the first task error. Inspect the log before resuming: %s',cleanNote);
    end
end
