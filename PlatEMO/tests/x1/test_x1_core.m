function test_x1_core()
%TEST_X1_CORE Pure-array invariants, without problem evaluations.
    s = rng; opt = x1_options('cooperative');
    R = [1,0; .9,.1; .8,.2; .2,.8; .1,.9; 0,1];
    R = R./vecnorm(R,2,2); opt.graphK = 1;
    [L,G] = x1_graph(R,[],opt);
    assert(isequal(G,G') && all(diag(G)==0) && all(sum(G,2)<=1));
    assert(any(isinf(L(:))),'Disconnected components must remain disconnected.');
    conf = ones(6,1); H = x1_cooperation_weights(L(1,:),1,1,opt,conf);
    assert(H(1)==1 && sum(H) <= 2+1e-12);   % the mass cap only shrinks
    conf(:) = 0; H = x1_cooperation_weights(L(1,:),1,1,opt,conf);
    assert(isequal(H,[1,0,0,0,0,0]));
    opt.graphShuffled = true; [Ls,Gs] = x1_graph(R,[],opt);
    assert(isequal(sort(sum(G,2)),sort(sum(Gs,2))) && all(diag(Ls)==0));
    legacy = [0,1,2;1,0,1;2,1,0];
    [L0,~] = x1_graph(eye(3),legacy,x1_options('identity'));
    assert(isequal(L0,legacy),'Identity must keep historical distances exactly.');
    Y = [.2,.7;1,0]; oi = [-10,3]; os = [20,4]; ni = [-11,2]; ns = [25,6];
    T = x1_transport(Y,oi,os,ni,ns);
    assert(max(abs((T.*ns+ni)-(Y.*os+oi)),[],'all')<1e-12);
    assert(isequal(x1_transport(Y,[],[],ni,ns),Y));
    h = x1_history_append([],reshape(1:12,6,2),(1:6)',zeros(6,0),4);
    assert(isequal(h.F,(3:6)') && size(h.X,1)==4 && size(h.C,2)==0);
    h = x1_history_append(h,[13,14],7,zeros(1,0),4);
    assert(isequal(h.F,(4:7)'));
    p = x1_parameters('g15'); assert(p{31}==0 && p{42}==0 && isempty(p{45}));
    p = x1_parameters('legacy'); assert(p{31}==.2 && p{42}==1 && isempty(p{45}));
    p = x1_parameters('cooperative_no_order'); assert(p{31}==0 && p{45}.massBudget==1);
    assert(isequal(s,rng),'Core helpers consumed random numbers.');
    fprintf('test_x1_core: all pure-array tests passed.\n');
end
