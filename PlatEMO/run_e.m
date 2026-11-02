function run_e(blocks)
%RUN_E  Phase E (see e_build_tasks), with the executor of phase D.
%   run_e             % E1 and E2
%   run_e('E1')
%   Resumable.

    if nargin < 1 || isempty(blocks), blocks = {'E1','E2'}; end
    if ischar(blocks), blocks = {blocks}; end
    for b = 1:numel(blocks)
        run_d_tasks(e_build_tasks(blocks{b}),['E-' blocks{b}],4);
    end
end
