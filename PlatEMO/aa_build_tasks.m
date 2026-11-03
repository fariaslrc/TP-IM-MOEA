function tasks = aa_build_tasks(block)
%AA_BUILD_TASKS  Phase AA: one evaluation per generation and a larger archive
%in the final TP-IM-MOEA (g15), under the protocol of the article (hard budget
%of 300 evaluations, IGD of the nondominated solutions among all evaluations,
%N = 50), WFG1-9 x m {3,6,9} x d {10,100}, 30 runs. Every task keeps the output
%name of the g15 run of block C1, hence its seed. Runs are not instrumented,
%so their times are comparable with each other.
%
%   AA0_g15       g15 itself, rerun on this PC (the IGD must equal that of C1;
%                 the time is the reference of this block)
%   AA1_batch1    one evaluation per generation (batchOne), chosen by the
%                 prescreening among the same 50 candidates
%   AA2_arc300    archive of capacity 300 instead of 2N = 100 (arcCap): with
%                 300 evaluations, no solution is ever discarded, and the map
%                 is trained on every nondominated solution found
%   AA3_both      AA1 and AA2 together
%
%   AA1  4 variants x 54 instances x 30 runs                          6,480
%
%   Output: Data_A/AA1/<config>/<name>.mat.

    if ~strcmp(block,'AA1'), error('Unknown block %s. Use AA1.',block); end
    root = fullfile(fileparts(mfilename('fullpath')),'Data_A',block);
    C1   = c_build_tasks('C1');
    base = C1(strcmp({C1.config},'g15'));
    %         name           batchOne arcCap
    V = {'AA0_g15',          0,       0
         'AA1_batch1',       1,       0
         'AA2_arc300',       0,       300
         'AA3_both',         1,       300};
    tasks = repmat(base(1),1,0);
    for v = 1 : size(V,1)
        T = base;
        for i = 1 : numel(T)
            p = T(i).param;
            p(end+1:44) = {[]};
            p(43:44) = V(v,2:3);                        % batchOne arcCap
            T(i).param  = p;
            T(i).config = V{v,1};
            T(i).checkArchive = V{v,3} == 0;            % the reported archive has 300 members, not 2N, with arcCap
            [~,name] = fileparts(T(i).outFile);
            T(i).outFile = fullfile(root,V{v,1},[name '.mat']);
        end
        tasks = [tasks, T]; %#ok<AGROW>
    end
    [tasks.crashTolerant] = deal(false);
end
