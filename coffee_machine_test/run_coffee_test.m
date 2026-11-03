% run_coffee_test.m - Complete all-in-one runner for Coffee Machine Vibration Classification
% Automatically ensures the MEX binary is compiled and executes the verification test suite.

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(scriptDir);

mexFile = fullfile(scriptDir, 'ei_classifier_mex');
if exist(mexFile, 'file') ~= 3
    fprintf('Compiled MEX file not found. Running build_mex now...\n');
    run(fullfile(scriptDir, 'build_mex.m'));
end

% Run full test suite
run(fullfile(scriptDir, 'test_coffee_classifier.m'));
