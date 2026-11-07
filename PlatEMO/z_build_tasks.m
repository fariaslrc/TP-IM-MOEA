function tasks = z_build_tasks(block)
%Z_BUILD_TASKS  Phase Z (version 2, 2026-11-05): the supporting experiments of the article
%regenerated with the final TP-IM-MOEA of phase AC, called F here: X1 (ordering phase in 20% of
%the epochs, nbPhase = 0.2, and the read-out on the cell of the parent, cellRead = 1) with the
%geometric ordering gate and the global affine repair triggered only while the archive has no
%feasible member (profile 'gated_repair_global' of x1_options).
%
%Every task is a g15-based task of the article with the same output name, hence the same seed;
%only the model changes. On a problem without constraints and with lattice resolution H1 >= 2
%(every task below except Z3: WFG and DTLZ with m <= 9) F is exactly X1, because the gate keeps
%the ordering and the repair never acts (checked by the smoke tests of phase AC and of this phase),
%so those tasks run X1 through the historical path (parameter 45 empty). Z3 (RWMOP) runs the
%complete F. Not rerun because they already exist with F on the same seeds: the main WFG grid
%(X1, phase X), m = 15 and 20 (X2, phase Y, which F equals there), DTLZ (X1, phase AB) and RWMOP
%(gated_repair_global, block AC4).
%
%   Z1  ablation, every configuration of block C3 (8)                     12,960
%   Z2  sensitivity: S1 and the Theta part of S2 (block C4)                 3,780
%   Z3  batch size on RWMOP, B0 in {5, 20} (block C5)                        240
%   Z4  anchors permuted 25/50/100% and the instrumented reference (F1)    6,480
%   Z5  prescreening controls, random and stratified (block G1)            3,240
%   Z6  topology on DTLZ, instrumented and all anchors permuted (G2)       1,800
%   Z7  budget, 600 and 1,000 evaluations (block H1, TP-IM-MOEA only)      1,080
%   Z8  population size, N = 30 and 100 (block I1)                           480
%   Z9  time: g15 and F on the 24 TP-IM-MOEA tasks of block D1, shuffled
%       together and run with 4 workers, for the cost ratio F/g15             48
%   Z10 clean ablation without the SOM in reproduction (block K1, topo = 4;
%       added after the first analysis of phase Z)                          1,620
%
%   Output: Data_Z/<block>/<config>/<name>.mat.

    root = fullfile(fileparts(mfilename('fullpath')),'Data_Z',block);
    switch block
        case 'Z1', T = c_build_tasks('C3');
        case 'Z2', T = c_build_tasks('C4');
        case 'Z3', T = c_build_tasks('C5'); T = T(ismember({T.config},{'b05_B0=5','b20_B0=20'}));
        case 'Z4', T = f_build_tasks('F1');
        case 'Z5', T = g_build_tasks('G1');
        case 'Z6', T = g_build_tasks('G2');
        case 'Z7', T = h_build_tasks('H1');
        case 'Z8', T = i_build_tasks('I1');
        case 'Z9', T = d_build_tasks('D1');
        case 'Z10', T = k_build_tasks('K1');            % clean ablation without the SOM (topo = 4)
        otherwise, error('Unknown block %s. Use Z1..Z10.',block);
    end
    T = T(strcmp({T.algName},'TPIMMOEA_X'));
    if strcmp(block,'Z9')
        G = T; [G.config] = deal('g15'); X = T; [X.config] = deal('F');
        T = [G, X];
    end
    for i = 1 : numel(T)
        p = T(i).param;
        p(end+1:45) = {[]};
        if ~(strcmp(block,'Z9') && strcmp(T(i).config,'g15'))
            p{31} = 0.2;                                % nbPhase: ordering phase in 20% of the epochs
            p{42} = 1;                                  % cellRead: cell of the graph neighbours
            if startsWith(T(i).probName,'RWMOP')
                p{45} = x1_options('gated_repair_global');   % ordering gate and global repair
            end
        end
        T(i).param = p;
        [~,name] = fileparts(T(i).outFile);
        T(i).outFile = fullfile(root,T(i).config,[name '.mat']);
    end
    if strcmp(block,'Z9')
        s = RandStream('mt19937ar','Seed',2027);         % shuffled, so both meet the same machine load
        T = T(randperm(s,numel(T)));
    end
    [T.crashTolerant] = deal(false);
    tasks = T;
end
