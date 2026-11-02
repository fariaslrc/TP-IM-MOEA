function [P,D] = repo_paths()
%REPO_PATHS  Folders used by the analysis scripts.
%   P  PlatEMO 4.16 with the overlay of this repository installed, given by
%      the environment variable PLATEMO_ROOT.
%   D  folder that holds the Data_<phase> folders written by the experiment
%      scripts, given by TPIM_DATA (P by default, where the scripts write).
%   Example: setenv('PLATEMO_ROOT','C:\PlatEMO\PlatEMO')

    P = getenv('PLATEMO_ROOT');
    if isempty(P) || ~exist(fullfile(P,'platemo.m'),'file')
        error('repo_paths:platemo','Set PLATEMO_ROOT to the PlatEMO folder that contains platemo.m.');
    end
    D = getenv('TPIM_DATA');
    if isempty(D), D = P; end
end
