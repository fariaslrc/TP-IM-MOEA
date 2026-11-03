function tasks = z_build_tasks(block)
%Z_BUILD_TASKS  Phase Z: the TP-IM-MOEA results of the article regenerated
%with X2, the final configuration adopted after phase Y (g15 with the read-out
%on the cell of the parent, cellRead = 1). Every task is a g15-based task of
%the article with the same output name, hence the same seed; only cellRead
%changes. Not rerun because they are already available or unchanged: the main
%WFG grid (X2 of block X1), m = 15 and 20, RWMOP and DTLZ (phase Y), the
%variant without anchors (cellRead needs the anchored map, so it equals the
%g15 run) and the variant without the SOM in reproduction (K1: the parent
%replaces the base point, so it equals the g15 run).
%
%   Z1  ablation: no decomposition infill, no reference-niche selection, no
%       prescreening, no LHS/duplicate rejection, neighbourhood, shuffled
%       neighbourhood (block C3)                                        9,720
%   Z2  sensitivity: S1 and the Theta part of S2 (block C4)             3,780
%   Z3  batch size on RWMOP, B0 in {5, 20} (block C5)                     240
%   Z4  anchors permuted, 25/50/100% (block F1)                         4,860
%   Z5  prescreening controls, random and stratified (block G1)         3,240
%   Z6  topology on DTLZ, instrumented and all anchors permuted (G2)    1,800
%   Z7  budget, 600 and 1,000 evaluations (block H1, TP-IM-MOEA only)   1,080
%   Z8  population size, N = 30 and 100 (block I1)                        480
%   Z9  time: g15 and X2 on the 24 TP-IM-MOEA tasks of block D1, shuffled
%       together and run with 4 workers, for the cost ratio X2/g15         48
%
%   Output: Data_Z/<block>/<config>/<name>.mat.

    root = fullfile(fileparts(mfilename('fullpath')),'Data_Z',block);
    switch block
        case 'Z1', T = c_build_tasks('C3'); T = T(ismember({T.config},{'q02_noInfillD','q03_noSelRef','q04_noPre','q05_noCheap','q07_withNbh','q08_withNbh_shuf'}));
        case 'Z2', T = c_build_tasks('C4');
        case 'Z3', T = c_build_tasks('C5'); T = T(ismember({T.config},{'b05_B0=5','b20_B0=20'}));
        case 'Z4', T = f_build_tasks('F1'); T = T(ismember({T.config},{'a025','a050','a100'}));
        case 'Z5', T = g_build_tasks('G1');
        case 'Z6', T = g_build_tasks('G2');
        case 'Z7', T = h_build_tasks('H1'); T = T(strcmp({T.algName},'TPIMMOEA_X'));
        case 'Z8', T = i_build_tasks('I1');
        case 'Z9', T = d_build_tasks('D1'); T = T(strcmp({T.algName},'TPIMMOEA_X'));
        otherwise, error('Unknown block %s. Use Z1..Z9.',block);
    end
    if strcmp(block,'Z9')
        G = T; [G.config] = deal('g15'); X = T; [X.config] = deal('X2');
        T = [G, X];
    end
    for i = 1 : numel(T)
        p = T(i).param;
        p(end+1:42) = {[]};
        if ~(strcmp(block,'Z9') && strcmp(T(i).config,'g15'))
            p{42} = 1;                                  % cellRead: the read-out of X2
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
