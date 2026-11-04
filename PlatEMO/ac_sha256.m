function h = ac_sha256(value,isFile)
%AC_SHA256 SHA-256 of a UTF-8 string, byte vector, or a file.
    if nargin < 2, isFile = false; end
    if isFile
        fid = fopen(value,'rb');
        assert(fid >= 0,'AC:HashRead','Cannot read %s.',value);
        cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
        bytes = fread(fid,Inf,'*uint8');
    elseif ischar(value) || isstring(value)
        bytes = unicode2native(char(value),'UTF-8');
    else
        bytes = uint8(value);
    end
    md = javaMethod('getInstance','java.security.MessageDigest','SHA-256');
    md.update(bytes(:));
    digest = typecast(md.digest(),'uint8');
    h = lower(reshape(dec2hex(digest,2).',1,[]));
end
