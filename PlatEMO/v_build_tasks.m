function tasks = v_build_tasks(block)
%V_BUILD_TASKS  Phase V: the reference directions of the final TP-IM-MOEA
%(g15). With N = 50, the Das-Dennis directions give 45, 42 and 45 nodes for
%m = 3, 6 and 9, and none of the 45 directions for m = 9 lies inside the
%simplex (9 vertices and 36 midpoints of edges). The weights of MOEA/D-UR
%give exactly N directions for any m, most of them inside the simplex.
%Protocol of the article (hard budget of 300 evaluations, IGD of the
%nondominated solutions among all evaluations, N = 50), WFG1-9 x m {3,6,9}
%x d {10,100}, 30 runs. Every task keeps the output name of the g15 run of
%block C1, hence its seed; the directions are drawn with a fixed seed of
%their own, so the run's random stream is unchanged. All runs are
%instrumented (instr = 1, which draws no random number).
%
%   V0_DasDennis   g15 itself (the IGD must equal that of C1 run by run)
%   V1_URmap       weights of MOEA/D-UR for the map only; prescreening and
%                  selection keep the Das-Dennis directions
%   V2_URall       weights of MOEA/D-UR for the map, the prescreening and the
%                  selection
%   V3_URDmap      as V1, with candidates uniform on the simplex (Dirichlet)
%   V4_URDall      as V2, with candidates uniform on the simplex (Dirichlet)
%
%   V1  5 variants x 54 instances x 30 runs                           8,100
%
%   Output: Data_V/V1/<config>/<name>.mat.

    if ~strcmp(block,'V1'), error('Unknown block %s. Use V1.',block); end
    root = fullfile(fileparts(mfilename('fullpath')),'Data_V',block);
    C1   = c_build_tasks('C1');
    base = C1(strcmp({C1.config},'g15'));
    %         name           refGen refScope
    V = {'V0_DasDennis',     0,     0
         'V1_URmap',         1,     1
         'V2_URall',         1,     0
         'V3_URDmap',        2,     1
         'V4_URDall',        2,     0};
    tasks = repmat(base(1),1,0);
    for v = 1 : size(V,1)
        T = base;
        for i = 1 : numel(T)
            p = T(i).param;
            p(end+1:38) = {[]};
            p{29} = 1;                                  % instr
            p(37:38) = V(v,2:3);                        % refGen refScope
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
