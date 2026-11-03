function tasks = x_build_tasks(block)
%X_BUILD_TASKS  Phase X: TPN, the final TP-IM-MOEA (g15) with the topology of
%the map used in training and in reproduction, and its three controls.
%Protocol of the article (hard budget of 300 evaluations, IGD of the
%nondominated solutions among all evaluations, N = 50), WFG1-9 x m {3,6,9}
%x d {10,100}, 30 runs. Every task keeps the output name of the g15 run of
%block C1, hence its seed. All runs are instrumented (instr = 1, which draws
%no random number).
%
%   Training: ordering phase in the first 20% of the epochs of each training
%   call (Gaussian neighbourhood on the reference graph, radius from 1 to 0.5
%   hops; variant A2 of phase T), then winner only.
%   Reproduction: the base point is the convex combination of the decision
%   prototypes of the parent's node j and of m-1 nodes updated in the current
%   training call, with the weights whose objective prototypes best reproduce
%   the parent (cell read-out).
%
%   X1_TPN         ordering phase; cell of j and its m-1 graph neighbours
%                  angularly nearest to the parent
%   X2_TPN_noOrd   X1 with winner-only training (no ordering phase)
%   X3_TPN_shuf    X1 with the graph of training and read-out permuted once
%                  per run
%   X4_Prox        winner-only training; cell of j and the m-1 nodes nearest
%                  to the parent in objective space, without the graph (the
%                  codebook control)
%   g15 (C1), A2B0 and A2B1 (T1) share the seeds and are not rerun.
%
%   X1  4 variants x 54 instances x 30 runs                           6,480
%
%   Output: Data_X/X1/<config>/<name>.mat.

    if ~strcmp(block,'X1'), error('Unknown block %s. Use X1.',block); end
    root = fullfile(fileparts(mfilename('fullpath')),'Data_X',block);
    C1   = c_build_tasks('C1');
    base = C1(strcmp({C1.config},'g15'));
    %         name             nbPhase graphShuf cellRead
    V = {'X1_TPN',             0.2,    0,        1
         'X2_TPN_noOrd',       0,      0,        1
         'X3_TPN_shuf',        0.2,    1,        1
         'X4_Prox',            0,      0,        2};
    tasks = repmat(base(1),1,0);
    for v = 1 : size(V,1)
        T = base;
        for i = 1 : numel(T)
            p = T(i).param;
            p(end+1:42) = {[]};
            p{29} = 1;                                  % instr
            p{31} = V{v,2};                             % nbPhase
            p{41} = V{v,3};                             % graphShuf
            p{42} = V{v,4};                             % cellRead
            T(i).param  = p;
            T(i).config = V{v,1};
            [~,name] = fileparts(T(i).outFile);
            T(i).outFile = fullfile(root,V{v,1},[name '.mat']);
        end
        tasks = [tasks, T]; %#ok<AGROW>
    end
    % An error in a variant is a defect of the new code, not of a compared
    % algorithm: it must fail the run (no file), so the audit reports it
    [tasks.crashTolerant] = deal(false);
end
