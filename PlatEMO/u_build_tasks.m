function tasks = u_build_tasks(block)
%U_BUILD_TASKS  Phase U: why the prototype of the parent's region is a
%better base point than the parent itself, in the final TP-IM-MOEA (g15),
%under the protocol of the article (hard budget of 300 evaluations, IGD of
%the nondominated solutions among all evaluations, N = 50), on WFG1-9 x
%m {3,6,9} x d {10,100}, 30 runs. Only the base point of reproduction
%changes. Every task keeps the output name of the g15 run of block C1,
%hence its seed, so the four variants are paired run by run with each other
%and with the published g15 runs. All runs are instrumented (instr = 1,
%which draws no random number) to record the base points (metric.protoLog).
%
%   U0_Prototype     prototype of the parent's region (g15 itself; the IGD
%                    must equal that of C1 run by run)
%   U1_RegionMean    mean of the current ND members of the region, the parent
%                    included: what the prototype summarizes, without memory
%                    across generations
%   U2_RegionMember  another ND member of the region drawn at random (the
%                    parent when it is alone): a point of the region, without
%                    averaging
%   U3_Parent        the parent itself (topo = 4, the clean noSOM of K1, here
%                    on the seeds of C1)
%
%   U1  4 variants x 54 instances x 30 runs                           6,480
%
%   Output: Data_U/U1/<config>/<name>.mat.

    if ~strcmp(block,'U1'), error('Unknown block %s. Use U1.',block); end
    root = fullfile(fileparts(mfilename('fullpath')),'Data_U',block);
    C1   = c_build_tasks('C1');
    base = C1(strcmp({C1.config},'g15'));
    %         name             baseMode topo
    V = {'U0_Prototype',       0,      2
         'U1_RegionMean',      1,      2
         'U2_RegionMember',    2,      2
         'U3_Parent',          0,      4};
    tasks = repmat(base(1),1,0);
    for v = 1 : size(V,1)
        T = base;
        for i = 1 : numel(T)
            p = T(i).param;
            if p{14} ~= 2, error('Unexpected topo in the g15 tasks of C1.'); end
            p(end+1:36) = {[]};
            p{29} = 1;                                  % instr
            p{36} = V{v,2};                             % baseMode
            p{14} = V{v,3};                             % topo, the 14th parameter of TPIMMOEA_X
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
