function Y = x1_transport(Y,oldIdeal,oldScale,newIdeal,newScale)
%X1_TRANSPORT Preserve raw objective prototypes under affine renormalization.
% Objective prototypes are not clipped to [0,1]: old extrema may be outside.
    if isempty(oldIdeal), return; end
    Y = (Y.*oldScale + oldIdeal - newIdeal)./newScale;
end
