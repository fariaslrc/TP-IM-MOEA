function tasks = te_build_tasks(block)
%TE_BUILD_TASKS  Phase TE (time, review of 2026-11-06): the optimization time of the final model F
%and of every compared algorithm, measured together in one controlled campaign on one machine.
%The tasks are those of block D1 (the 16 algorithms of the article on WFG2, WFG4, WFG6 and WFG9 with
%(m,d) in {(3,10),(9,100)}, runs 1-3; K-RVEA at d = 10 only), plus the same 24 tasks with the final
%model F, which on these unconstrained problems with lattice resolution H1 >= 2 is X1 (nbPhase 0.2,
%cellRead 1). Every task keeps the file name, hence the seed, of block D1. The whole list is
%shuffled and run with 4 workers, so that every algorithm meets the same machine load.
%
%   TE1  372 tasks of D1 + 24 tasks of F                                         396
%
%   Output: Data_TE/TE1/<config>/<name>.mat; the time is metric.tSolve (optimization only, run_one_d_task).

    if ~strcmp(block,'TE1'), error('Unknown block %s. Use TE1.',block); end
    root = fullfile(fileparts(mfilename('fullpath')),'Data_TE',block);
    T = d_build_tasks('D1');
    G = T(strcmp({T.algName},'TPIMMOEA_X'));
    for i = 1 : numel(G)
        p = G(i).param; p(end+1:45) = {[]};
        p{31} = 0.2; p{42} = 1;                     % F = X1 here (no constraints, H1 >= 2)
        G(i).param = p; G(i).config = 'F';
    end
    T = [T, G];
    for i = 1 : numel(T)
        [~,name] = fileparts(T(i).outFile);
        T(i).outFile = fullfile(root,T(i).config,[name '.mat']);
    end
    s = RandStream('mt19937ar','Seed',2026);
    tasks = T(randperm(s,numel(T)));
end
