function host = ac_check_host()
%AC_CHECK_HOST Guard against starting a long campaign on the wrong machine:
%real execution requires TPIMMOEA_EXECUTION_HOST to name this computer
%(its COMPUTERNAME). Dry runs need no host configuration.
    host = getenv('COMPUTERNAME');
    target = getenv('TPIMMOEA_EXECUTION_HOST');
    assert(~isempty(target) && ~isempty(host) && strcmpi(strtrim(target),strtrim(host)), ...
        'AC:Host','Real execution requires TPIMMOEA_EXECUTION_HOST set to this computer''s COMPUTERNAME. Dry runs need no host configuration.');
end
