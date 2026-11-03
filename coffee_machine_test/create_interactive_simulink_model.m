% create_interactive_simulink_model.m
% Generates 'coffee_machine_interactive.slx' with interactive toggle switches,
% continuous waveform generators, real-time pacing, and live scopes.

fprintf('=== Creating Interactive Edge Impulse Simulink Model ===\n');

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(scriptDir);

modelName = 'coffee_machine_interactive';

% Close if already open
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

% Create new model
new_system(modelName);

% Configure solver: Fixed-step discrete at 100 Hz (0.01s)
set_param(modelName, 'SolverType', 'Fixed-step');
set_param(modelName, 'Solver', 'FixedStepDiscrete');
set_param(modelName, 'FixedStep', '0.01');
set_param(modelName, 'StopTime', 'inf'); % Run continuously for live interaction

% Enable Real-Time Pacing (1 simulation second = 1 wall-clock second)
set_param(modelName, 'EnablePacing', 'on');
set_param(modelName, 'PacingRate', 1.0);

% -------------------------------------------------------------------------
% 1. Helper function to create Subsystems for each machine stage
% -------------------------------------------------------------------------

% Subsystem A: IDLE (accZ ~ 9.8, accY ~ 0, accX ~ 0 + subtle sensor noise)
subIdle = [modelName '/Stage_IDLE'];
add_block('simulink/Ports & Subsystems/Subsystem', subIdle, 'Position', [50, 50, 150, 110]);
delete_line(subIdle, 'In1/1', 'Out1/1');
delete_block([subIdle '/In1']);

add_block('simulink/Sources/Constant', [subIdle '/Gravity_Z'], 'Value', '9.8', 'SampleTime', '0.01', 'Position', [20, 20, 60, 40]);
add_block('simulink/Sources/Random Number', [subIdle '/Noise_Z'], 'Mean', '0', 'Variance', '0.0025', 'SampleTime', '0.01', 'Position', [20, 60, 60, 80]);
add_block('simulink/Math Operations/Sum', [subIdle '/Sum_Z'], 'Inputs', '++', 'Position', [90, 30, 110, 60]);
add_line(subIdle, 'Gravity_Z/1', 'Sum_Z/1');
add_line(subIdle, 'Noise_Z/1', 'Sum_Z/2');

add_block('simulink/Sources/Random Number', [subIdle '/Noise_Y'], 'Mean', '0', 'Variance', '0.0025', 'SampleTime', '0.01', 'Position', [20, 100, 60, 120]);
add_block('simulink/Sources/Random Number', [subIdle '/Noise_X'], 'Mean', '0', 'Variance', '0.0025', 'SampleTime', '0.01', 'Position', [20, 140, 60, 160]);

add_block('simulink/Signal Routing/Mux', [subIdle '/Mux_3Axis'], 'Inputs', '3', 'Position', [150, 40, 160, 150]);
add_line(subIdle, 'Sum_Z/1', 'Mux_3Axis/1');
add_line(subIdle, 'Noise_Y/1', 'Mux_3Axis/2');
add_line(subIdle, 'Noise_X/1', 'Mux_3Axis/3');
add_line(subIdle, 'Mux_3Axis/1', 'Out1/1');

% Subsystem B: GRIND (Violent wideband vibration)
subGrind = [modelName '/Stage_GRIND'];
add_block('simulink/Ports & Subsystems/Subsystem', subGrind, 'Position', [50, 150, 150, 210]);
delete_line(subGrind, 'In1/1', 'Out1/1');
delete_block([subGrind '/In1']);

add_block('simulink/Sources/Constant', [subGrind '/Gravity_Z'], 'Value', '9.8', 'SampleTime', '0.01', 'Position', [20, 20, 60, 40]);
add_block('simulink/Sources/Random Number', [subGrind '/Vib_Z'], 'Mean', '0', 'Variance', '64.0', 'SampleTime', '0.01', 'Position', [20, 60, 60, 80]);
add_block('simulink/Math Operations/Sum', [subGrind '/Sum_Z'], 'Inputs', '++', 'Position', [90, 30, 110, 60]);
add_line(subGrind, 'Gravity_Z/1', 'Sum_Z/1');
add_line(subGrind, 'Vib_Z/1', 'Sum_Z/2');

add_block('simulink/Sources/Random Number', [subGrind '/Vib_Y'], 'Mean', '0', 'Variance', '36.0', 'SampleTime', '0.01', 'Position', [20, 100, 60, 120]);
add_block('simulink/Sources/Random Number', [subGrind '/Vib_X'], 'Mean', '0', 'Variance', '25.0', 'SampleTime', '0.01', 'Position', [20, 140, 60, 160]);

add_block('simulink/Signal Routing/Mux', [subGrind '/Mux_3Axis'], 'Inputs', '3', 'Position', [150, 40, 160, 150]);
add_line(subGrind, 'Sum_Z/1', 'Mux_3Axis/1');
add_line(subGrind, 'Vib_Y/1', 'Mux_3Axis/2');
add_line(subGrind, 'Vib_X/1', 'Mux_3Axis/3');
add_line(subGrind, 'Mux_3Axis/1', 'Out1/1');

% Subsystem C: PUMP (50 Hz motor hum + harmonics)
subPump = [modelName '/Stage_PUMP'];
add_block('simulink/Ports & Subsystems/Subsystem', subPump, 'Position', [50, 250, 150, 310]);
delete_line(subPump, 'In1/1', 'Out1/1');
delete_block([subPump '/In1']);

add_block('simulink/Sources/Constant', [subPump '/Gravity_Z'], 'Value', '9.8', 'SampleTime', '0.01', 'Position', [20, 10, 60, 30]);
add_block('simulink/Sources/Sine Wave', [subPump '/Sine_Z'], 'Amplitude', '2.5', 'Frequency', '2*pi*50', 'SampleTime', '0.01', 'Position', [20, 40, 60, 60]);
add_block('simulink/Sources/Random Number', [subPump '/Noise_Z'], 'Mean', '0', 'Variance', '0.09', 'SampleTime', '0.01', 'Position', [20, 70, 60, 90]);
add_block('simulink/Math Operations/Sum', [subPump '/Sum_Z'], 'Inputs', '+++', 'Position', [90, 30, 110, 70]);
add_line(subPump, 'Gravity_Z/1', 'Sum_Z/1');
add_line(subPump, 'Sine_Z/1', 'Sum_Z/2');
add_line(subPump, 'Noise_Z/1', 'Sum_Z/3');

add_block('simulink/Sources/Sine Wave', [subPump '/Sine_Y'], 'Amplitude', '1.8', 'Frequency', '2*pi*50', 'Phase', 'pi/2', 'SampleTime', '0.01', 'Position', [20, 105, 60, 125]);
add_block('simulink/Sources/Random Number', [subPump '/Noise_Y'], 'Mean', '0', 'Variance', '0.04', 'SampleTime', '0.01', 'Position', [20, 130, 60, 150]);
add_block('simulink/Math Operations/Sum', [subPump '/Sum_Y'], 'Inputs', '++', 'Position', [90, 110, 110, 140]);
add_line(subPump, 'Sine_Y/1', 'Sum_Y/1');
add_line(subPump, 'Noise_Y/1', 'Sum_Y/2');

add_block('simulink/Sources/Sine Wave', [subPump '/Sine_X'], 'Amplitude', '1.2', 'Frequency', '2*pi*25', 'SampleTime', '0.01', 'Position', [20, 165, 60, 185]);
add_block('simulink/Sources/Random Number', [subPump '/Noise_X'], 'Mean', '0', 'Variance', '0.04', 'SampleTime', '0.01', 'Position', [20, 190, 60, 210]);
add_block('simulink/Math Operations/Sum', [subPump '/Sum_X'], 'Inputs', '++', 'Position', [90, 170, 110, 200]);
add_line(subPump, 'Sine_X/1', 'Sum_X/1');
add_line(subPump, 'Noise_X/1', 'Sum_X/2');

add_block('simulink/Signal Routing/Mux', [subPump '/Mux_3Axis'], 'Inputs', '3', 'Position', [150, 40, 160, 180]);
add_line(subPump, 'Sum_Z/1', 'Mux_3Axis/1');
add_line(subPump, 'Sum_Y/1', 'Mux_3Axis/2');
add_line(subPump, 'Sum_X/1', 'Mux_3Axis/3');
add_line(subPump, 'Mux_3Axis/1', 'Out1/1');

% Subsystem D: EXTRACT (Espresso extraction under pressure)
subExtract = [modelName '/Stage_EXTRACT'];
add_block('simulink/Ports & Subsystems/Subsystem', subExtract, 'Position', [50, 350, 150, 410]);
delete_line(subExtract, 'In1/1', 'Out1/1');
delete_block([subExtract '/In1']);

add_block('simulink/Sources/Constant', [subExtract '/Gravity_Z'], 'Value', '9.8', 'SampleTime', '0.01', 'Position', [20, 10, 60, 30]);
add_block('simulink/Sources/Sine Wave', [subExtract '/Sine_Z'], 'Amplitude', '1.2', 'Frequency', '2*pi*50', 'SampleTime', '0.01', 'Position', [20, 40, 60, 60]);
add_block('simulink/Sources/Random Number', [subExtract '/Noise_Z'], 'Mean', '0', 'Variance', '0.16', 'SampleTime', '0.01', 'Position', [20, 70, 60, 90]);
add_block('simulink/Math Operations/Sum', [subExtract '/Sum_Z'], 'Inputs', '+++', 'Position', [90, 30, 110, 70]);
add_line(subExtract, 'Gravity_Z/1', 'Sum_Z/1');
add_line(subExtract, 'Sine_Z/1', 'Sum_Z/2');
add_line(subExtract, 'Noise_Z/1', 'Sum_Z/3');

add_block('simulink/Sources/Sine Wave', [subExtract '/Sine_Y'], 'Amplitude', '0.8', 'Frequency', '2*pi*50', 'Phase', 'pi/2', 'SampleTime', '0.01', 'Position', [20, 105, 60, 125]);
add_block('simulink/Sources/Random Number', [subExtract '/Noise_Y'], 'Mean', '0', 'Variance', '0.09', 'SampleTime', '0.01', 'Position', [20, 130, 60, 150]);
add_block('simulink/Math Operations/Sum', [subExtract '/Sum_Y'], 'Inputs', '++', 'Position', [90, 110, 110, 140]);
add_line(subExtract, 'Sine_Y/1', 'Sum_Y/1');
add_line(subExtract, 'Noise_Y/1', 'Sum_Y/2');

add_block('simulink/Sources/Sine Wave', [subExtract '/Sine_X'], 'Amplitude', '0.6', 'Frequency', '2*pi*25', 'SampleTime', '0.01', 'Position', [20, 165, 60, 185]);
add_block('simulink/Sources/Random Number', [subExtract '/Noise_X'], 'Mean', '0', 'Variance', '0.09', 'SampleTime', '0.01', 'Position', [20, 190, 60, 210]);
add_block('simulink/Math Operations/Sum', [subExtract '/Sum_X'], 'Inputs', '++', 'Position', [90, 170, 110, 200]);
add_line(subExtract, 'Sine_X/1', 'Sum_X/1');
add_line(subExtract, 'Noise_X/1', 'Sum_X/2');

add_block('simulink/Signal Routing/Mux', [subExtract '/Mux_3Axis'], 'Inputs', '3', 'Position', [150, 40, 160, 180]);
add_line(subExtract, 'Sum_Z/1', 'Mux_3Axis/1');
add_line(subExtract, 'Sum_Y/1', 'Mux_3Axis/2');
add_line(subExtract, 'Sum_X/1', 'Mux_3Axis/3');
add_line(subExtract, 'Mux_3Axis/1', 'Out1/1');

% -------------------------------------------------------------------------
% 2. Cascaded Interactive Manual Switches (Double-click to toggle!)
% -------------------------------------------------------------------------
% Switch 3: PUMP (Upper) vs EXTRACT (Lower)
add_block('simulink/Signal Routing/Manual Switch', [modelName '/Switch_Pump_vs_Extract'], ...
    'Position', [240, 280, 280, 340], 'sw', '1');
add_line(modelName, 'Stage_PUMP/1', 'Switch_Pump_vs_Extract/1');
add_line(modelName, 'Stage_EXTRACT/1', 'Switch_Pump_vs_Extract/2');

% Switch 2: GRIND (Upper) vs (Pump or Extract) (Lower)
add_block('simulink/Signal Routing/Manual Switch', [modelName '/Switch_Grind_vs_Fluids'], ...
    'Position', [340, 200, 380, 260], 'sw', '1');
add_line(modelName, 'Stage_GRIND/1', 'Switch_Grind_vs_Fluids/1');
add_line(modelName, 'Switch_Pump_vs_Extract/1', 'Switch_Grind_vs_Fluids/2');

% Switch 1 (Master): IDLE (Upper) vs ACTIVE BREWING (Lower)
add_block('simulink/Signal Routing/Manual Switch', [modelName '/Toggle_IDLE_vs_ACTIVE'], ...
    'Position', [440, 120, 480, 180], 'sw', '1');
add_line(modelName, 'Stage_IDLE/1', 'Toggle_IDLE_vs_ACTIVE/1');
add_line(modelName, 'Switch_Grind_vs_Fluids/1', 'Toggle_IDLE_vs_ACTIVE/2');

% -------------------------------------------------------------------------
% 3. Edge Impulse S-Function Block
% -------------------------------------------------------------------------
add_block('simulink/User-Defined Functions/S-Function', ...
    [modelName '/Edge_Impulse_Classifier'], ...
    'Position', [560, 110, 740, 190], ...
    'FunctionName', 'ei_classifier_sfun', ...
    'Parameters', '0.01, 10');

add_line(modelName, 'Toggle_IDLE_vs_ACTIVE/1', 'Edge_Impulse_Classifier/1');

% -------------------------------------------------------------------------
% 4. Live Scopes
% -------------------------------------------------------------------------
% Scope 1: Live 3-Axis Vibration Stream
add_block('simulink/Sinks/Scope', [modelName '/Scope_Live_Vibration'], ...
    'Position', [560, 40, 600, 80]);
add_line(modelName, 'Toggle_IDLE_vs_ACTIVE/1', 'Scope_Live_Vibration/1');

% Scope 2: Real-Time Predicted Stage (1: extract, 2: grind, 3: idle, 4: pump)
add_block('simulink/Sinks/Scope', [modelName '/Scope_Stage_Prediction'], ...
    'Position', [820, 105, 860, 145]);
add_line(modelName, 'Edge_Impulse_Classifier/1', 'Scope_Stage_Prediction/1');

% Scope 3: 4-Class Probabilities
add_block('simulink/Sinks/Scope', [modelName '/Scope_Probabilities'], ...
    'Position', [820, 155, 860, 195]);
add_line(modelName, 'Edge_Impulse_Classifier/2', 'Scope_Probabilities/1');

% Scope 4: Best Confidence Score
add_block('simulink/Sinks/Scope', [modelName '/Scope_Confidence'], ...
    'Position', [820, 205, 860, 245]);
add_line(modelName, 'Edge_Impulse_Classifier/3', 'Scope_Confidence/1');

% Save model
slxPath = fullfile(scriptDir, [modelName '.slx']);
save_system(modelName, slxPath);
close_system(modelName);

fprintf('SUCCESS: %s created and saved!\n', slxPath);
