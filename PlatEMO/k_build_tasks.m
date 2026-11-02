function tasks = k_build_tasks(block)
%K_BUILD_TASKS  Phase K: single-factor ablation of the SOM in reproduction.
%The noSOM variant of block C3 (topo = 3) replaces the prototype by the
%parent but keeps the lattice neighbourhood, which activates the filling of
%empty niches from neighbouring regions. Variant topo = 4 replaces the
%prototype by the parent and keeps everything else of g15, including the
%absence of neighbourhood. Protocol of phase C (hard budget of 300
%evaluations, IGD of the nondominated solutions among all evaluations).
%
%   K1  noSOM with topo = 4, WFG1-9 x m {3,6,9} x d {10,100}, 30 runs     1,620
%
%   The tasks are those of the noSOM variant of C3, with the same file
%   names (hence the same seeds); only topo changes, from 3 to 4.
%   Output: Data_K/<block>/q06b_noSOM/<name>.mat.

    if ~strcmp(block,'K1'), error('Unknown block %s. Use K1.',block); end
    root  = fullfile(fileparts(mfilename('fullpath')),'Data_K',block);
    T     = c_build_tasks('C3');
    tasks = T(strcmp({T.config},'q06_noSOM'));
    for i = 1 : numel(tasks)
        p = tasks(i).param;
        if p{14} ~= 3, error('Unexpected topo in the noSOM tasks of C3.'); end
        p{14} = 4;                                  % topo, the 14th parameter of TPIMMOEA_X
        tasks(i).param  = p;
        tasks(i).config = 'q06b_noSOM';
        [~,name] = fileparts(tasks(i).outFile);
        tasks(i).outFile = fullfile(root,'q06b_noSOM',[name '.mat']);
    end
end
