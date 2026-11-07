function host = ac_check_host()
%AC_CHECK_HOST Explicit CASA attestation plus actual Windows hostname match.
    host = getenv('COMPUTERNAME');
    target = getenv('TPIMMOEA_CASA_HOSTNAME');
    assert(strcmpi(getenv('TPIMMOEA_EXECUTION_HOST'),'CASA') && ...
        ~isempty(target) && ~isempty(host) && strcmpi(strtrim(target),strtrim(host)), ...
        'AC:Host','Real execution is CASA only. On CASA set TPIMMOEA_EXECUTION_HOST=CASA and TPIMMOEA_CASA_HOSTNAME to its actual COMPUTERNAME. Dry runs need no host configuration.');
end
