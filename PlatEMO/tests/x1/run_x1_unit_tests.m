function run_x1_unit_tests()
%RUN_X1_UNIT_TESTS Component checks only; no PROBLEM or benchmark is run.
    here = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(here));
    addpath(fullfile(root,'Algorithms','Multi-objective optimization','TPIMMOEA_X1'));
    addpath(here);
    test_x1_core();
    test_x1_movement();
    test_x1_repair();
end
