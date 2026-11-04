function ac_verify_provenance(source)
%AC_VERIFY_PROVENANCE Check each worker's resolved code against the manifest.
% Rehash once per worker unless a resolved path, size, or timestamp changes.
    persistent lastSignature
    assert(source.ready,'AC:Installation','Manifest contains unresolved runtime dependencies.');
    assert(strcmp(source.matlabVersion,version) && strcmp(source.computer,computer), ...
        'AC:WorkerEnvironment','Worker MATLAB version/platform differs from the manifest.');
    paths = cell(1,numel(source.files));
    stamps = cell(1,numel(source.files));
    for i = 1:numel(source.files)
        paths{i} = which(source.files(i).name);
        d = dir(paths{i});
        if isempty(d), stamps{i} = []; else, stamps{i} = [d(1).bytes,d(1).datenum]; end
    end
    signature = ac_sha256(jsonencode({source.digest,paths,stamps}));
    if strcmp(lastSignature,signature), return; end
    for i = 1:numel(source.files)
        p = paths{i};
        if exist(p,'file') == 2, actual = ac_sha256(p,true);
        elseif isempty(p), actual = 'UNRESOLVED';
        else, actual = ac_sha256(p); end
        assert(strcmp(actual,source.files(i).sha256),'AC:WorkerSource', ...
            'Resolved source differs from manifest: %s (%s).',source.files(i).name,p);
    end
    lastSignature = signature;
end
