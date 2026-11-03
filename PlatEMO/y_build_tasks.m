function tasks = y_build_tasks(block)
%Y_BUILD_TASKS  Phase Y: confirmation of X2, the final TP-IM-MOEA (g15) with
%the read-out on the cell of the parent (cellRead = 1) and winner-only
%training, on the suites that did not take part in its selection. Every task
%is a g15 task of the article with the same output name, hence the same
%seed; only cellRead changes. Runs are not instrumented.
%
%   Y1  WFG1-9, m {15,20}, d {(m-1)+10, 100}, 300 evaluations (block C2)  1,080
%   Y2  RWMOP1-35, settings of Kumar et al., final population (block C5)  1,050
%   Y3  DTLZ1-4, 7, m {3,6,9}, d {10,100}, 300 evaluations (block D2)       900
%
%   Output: Data_Y/<block>/X2/<name>.mat.

    switch block
        case 'Y1', T = c_build_tasks('C2');
        case 'Y2', T = c_build_tasks('C5');
        case 'Y3', T = d_build_tasks('D2');
        otherwise, error('Unknown block %s. Use Y1, Y2 or Y3.',block);
    end
    T = T(strcmp({T.config},'g15'));
    root = fullfile(fileparts(mfilename('fullpath')),'Data_Y',block,'X2');
    for i = 1 : numel(T)
        p = T(i).param;
        p(end+1:42) = {[]};
        p{42} = 1;                                      % cellRead: cell of the graph neighbours
        T(i).param  = p;
        T(i).config = 'X2';
        [~,name] = fileparts(T(i).outFile);
        T(i).outFile = fullfile(root,[name '.mat']);
    end
    [T.crashTolerant] = deal(false);                    % an error is a defect of the variant
    tasks = T;
end
