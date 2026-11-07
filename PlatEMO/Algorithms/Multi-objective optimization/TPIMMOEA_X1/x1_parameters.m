function p = x1_parameters(profile,outN)
%X1_PARAMETERS Parameter vector of TPIMMOEA_X, including opt-in slot 45.
    if nargin < 1 || isempty(profile), profile = 'cooperative'; end
    if nargin < 2, outN = 0; end
    validateattributes(outN,{'numeric','logical'},{'scalar','binary'});
    p = {[],0.2,1,10,0.5,0.9,1,0,1,1,5,2,1,2,1,1,1,1,1,0.3, ...
         1,0,0,3,5,1000,outN,0,0,0,0.2,0,0,0,0,0,0,0,0,0,0,1,0,0,[]};
    if strcmp(profile,'g15')
        p{31} = 0; p{42} = 0;
    elseif ~strcmp(profile,'legacy')
        p{45} = x1_options(profile);
        if strcmp(profile,'cooperative_no_order'), p{31} = 0; end
    end
    % instr=0: phase AC diagnostics never call CalObj or CalCon out of budget.
    assert(p{29} == 0 && numel(p) == 45);
end
