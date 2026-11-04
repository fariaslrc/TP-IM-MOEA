function tasks = ab_build_tasks(block)
%AB_BUILD_TASKS  Phase AB: X1 (TPN), the final TP-IM-MOEA (g15) with the
%ordering phase in training (nbPhase = 0.2, variant A2 of phase T) and the
%read-out on the cell of the parent (cellRead = 1), on the suites of phase Y,
%where X2 (the same without the ordering phase) was run. Every task is a g15
%task of the article with the same output name, hence the same seed; only
%nbPhase and cellRead change. Runs are not instrumented.
%
%   AB1 WFG1-9, m {15,20}, d {(m-1)+10, 100}, 300 evaluations (block C2)  1,080
%   AB2 RWMOP1-35, settings of Kumar et al., final population (block C5)  1,050
%   AB3 DTLZ1-4, 7, m {3,6,9}, d {10,100}, 300 evaluations (block D2)       900
%
%   Output: Data_A/<block>/X1/<name>.mat.

    switch block
        case 'AB1', T = c_build_tasks('C2');
        case 'AB2', T = c_build_tasks('C5');
        case 'AB3', T = d_build_tasks('D2');
        otherwise, error('Unknown block %s. Use AB1, AB2 or AB3.',block);
    end
    T = T(strcmp({T.config},'g15'));
    root = fullfile(fileparts(mfilename('fullpath')),'Data_A',block,'X1');
    for i = 1 : numel(T)
        p = T(i).param;
        p(end+1:42) = {[]};
        p{31} = 0.2;                                    % nbPhase: ordering phase in 20% of the epochs
        p{42} = 1;                                      % cellRead: cell of the graph neighbours
        T(i).param  = p;
        T(i).config = 'X1';
        [~,name] = fileparts(T(i).outFile);
        T(i).outFile = fullfile(root,[name '.mat']);
    end
    [T.crashTolerant] = deal(false);                    % an error is a defect of the variant
    tasks = T;
end
