% create_coffee_simulink_model.m
% Creates and saves 'coffee_machine_sim.slx' with the Edge Impulse S-Function block.

fprintf('=== Creating Edge Impulse Coffee Machine Simulink Model ===\n');

baseDir = fileparts(mfilename('fullpath'));
if isempty(baseDir)
    baseDir = pwd;
end
addpath(baseDir);

modelName = 'coffee_machine_sim';

% Close if already open
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

% Create new model
new_system(modelName);

% Set solver properties: Fixed-step discrete solver at 100 Hz (0.01 s)
set_param(modelName, 'SolverType', 'Fixed-step');
set_param(modelName, 'Solver', 'FixedStepDiscrete');
set_param(modelName, 'FixedStep', '0.01');
set_param(modelName, 'StopTime', '12.0');

% -------------------------------------------------------------------------
% 1. Add "From Workspace" Block for 3-Axis Vibration Input
% -------------------------------------------------------------------------
add_block('simulink/Sources/From Workspace', [modelName '/Vibration_Data'], ...
    'Position', [50, 100, 180, 140], ...
    'VariableName', 'vibration_input', ...
    'SampleTime', '0.01', ...
    'Interpolate', 'on');

% -------------------------------------------------------------------------
% 2. Add Edge Impulse S-Function Block
% -------------------------------------------------------------------------
add_block('simulink/User-Defined Functions/S-Function', ...
    [modelName '/Edge_Impulse_Classifier'], ...
    'Position', [250, 80, 430, 160], ...
    'FunctionName', 'ei_classifier_sfun', ...
    'Parameters', '0.01, 10');

% Connect Vibration_Data -> S-Function input
add_line(modelName, 'Vibration_Data/1', 'Edge_Impulse_Classifier/1');

% -------------------------------------------------------------------------
% 3. Add Scopes & Outports
% -------------------------------------------------------------------------
% Scope 1: Input Vibration Signal
add_block('simulink/Sinks/Scope', [modelName '/Scope_Vibration'], ...
    'Position', [250, 20, 290, 60]);
add_line(modelName, 'Vibration_Data/1', 'Scope_Vibration/1');

% Scope 2: Predicted Stage ID (1: extract, 2: grind, 3: idle, 4: pump)
add_block('simulink/Sinks/Scope', [modelName '/Scope_Stage_Prediction'], ...
    'Position', [500, 75, 540, 105]);
add_line(modelName, 'Edge_Impulse_Classifier/1', 'Scope_Stage_Prediction/1');

% Scope 3: 4-Class Probabilities
add_block('simulink/Sinks/Scope', [modelName '/Scope_Probabilities'], ...
    'Position', [500, 115, 540, 145]);
add_line(modelName, 'Edge_Impulse_Classifier/2', 'Scope_Probabilities/1');

% Scope 4: Best Confidence Score
add_block('simulink/Sinks/Scope', [modelName '/Scope_Confidence'], ...
    'Position', [500, 155, 540, 185]);
add_line(modelName, 'Edge_Impulse_Classifier/3', 'Scope_Confidence/1');

% Outports to log data back to MATLAB
add_block('simulink/Sinks/Out1', [modelName '/out_stage_id'], ...
    'Position', [560, 80, 590, 100]);
add_line(modelName, 'Edge_Impulse_Classifier/1', 'out_stage_id/1');

add_block('simulink/Sinks/Out1', [modelName '/out_probs'], ...
    'Position', [560, 120, 590, 140]);
add_line(modelName, 'Edge_Impulse_Classifier/2', 'out_probs/1');

% Save model
slxPath = fullfile(baseDir, [modelName '.slx']);
save_system(modelName, slxPath);
close_system(modelName);

fprintf('SUCCESS: %s created and saved!\n', slxPath);
