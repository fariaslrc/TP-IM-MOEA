function tasks = w_build_tasks(block)
%W_BUILD_TASKS  Phase W: uses of the topology of the map in reproduction, in
%the final TP-IM-MOEA (g15), each with a control that removes the topology.
%Protocol of the article (hard budget of 300 evaluations, IGD of the
%nondominated solutions among all evaluations, N = 50), WFG1-9 x m {3,6,9}
%x d {10,100}, 30 runs. Every task keeps the output name of the g15 run of
%block C1, hence its seed. All runs are instrumented (instr = 1, which draws
%no random number).
%
%   W1_Fill             gap filling: half of the candidates target an empty
%                       niche from the representatives of its occupied
%                       neighbours on the reference graph (2 hops, 1/hop)
%   W1s_FillShuf        W1 with the graph permuted once per run
%   W2_Interp           piecewise-linear read-out at the parent: convex
%                       combination of the prototypes of the parent's node and
%                       of its trained graph neighbours (1 hop)
%   W2s_InterpShuf      W2 with the graph permuted once per run
%   W2p_InterpProx      W2 with as many trained nodes, the nearest in
%                       objective space, instead of the graph (codebook control)
%   W3_FillLocal        gap filling within 1 hop, equal weights, a
%                       representative that jumps in decision space excluded
%   W3s_FillLocalShuf   W3 with the graph permuted once per run
%   W4_InterpFillLocal  W2 and W3 together
%
%   W1  8 variants x 54 instances x 30 runs                          12,960
%
%   Output: Data_W/W1/<config>/<name>.mat.

    if ~strcmp(block,'W1'), error('Unknown block %s. Use W1.',block); end
    root = fullfile(fileparts(mfilename('fullpath')),'Data_W',block);
    C1   = c_build_tasks('C1');
    base = C1(strcmp({C1.config},'g15'));
    %         name                  fill interp graphShuf
    V = {'W1_Fill',                 1,   0,     0
         'W1s_FillShuf',            1,   0,     1
         'W2_Interp',               0,   1,     0
         'W2s_InterpShuf',          0,   1,     1
         'W2p_InterpProx',          0,   2,     0
         'W3_FillLocal',            2,   0,     0
         'W3s_FillLocalShuf',       2,   0,     1
         'W4_InterpFillLocal',      2,   1,     0};
    tasks = repmat(base(1),1,0);
    for v = 1 : size(V,1)
        T = base;
        for i = 1 : numel(T)
            p = T(i).param;
            p(end+1:41) = {[]};
            p{29} = 1;                                  % instr
            p(39:41) = V(v,2:4);                        % fill interp graphShuf
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
