% run_simulink_simulation.m
% Runs a 12-second real-time streaming simulation in Simulink using
% the Edge Impulse Coffee Machine Vibration Classifier S-Function.

fprintf('=================================================================\n');
fprintf('  Edge Impulse Simulink Real-Time Streaming Simulation Runner   \n');
fprintf('=================================================================\n\n');

scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(scriptDir);

% 1. Ensure prerequisites exist
sfunFile = fullfile(scriptDir, ['ei_classifier_sfun.' mexext]);
if exist(sfunFile, 'file') ~= 3
    fprintf('S-Function binary not found. Building it now...\n');
    run(fullfile(scriptDir, 'build_sfun.m'));
end

slxFile = fullfile(scriptDir, 'coffee_machine_sim.slx');
if exist(slxFile, 'file') ~= 4
    fprintf('Simulink model not found. Generating it now...\n');
    run(fullfile(scriptDir, 'create_coffee_simulink_model.m'));
end

% -------------------------------------------------------------------------
% 2. Synthesize a 12-Second Continuous Multi-Stage Vibration Profile
% -------------------------------------------------------------------------
% The Edge Impulse model expects 3-axis vibration [accZ, accY, accX] at 100 Hz.
% We simulate a full automated coffee brewing cycle across 12 seconds:
%   0.0s - 3.0s  : IDLE    (resting on kitchen counter, gravity ~9.8 on Z)
%   3.0s - 6.0s  : GRIND   (violent high-frequency bean crushing vibration)
%   6.0s - 9.0s  : PUMP    (50 Hz water pump pressurizing boiler)
%   9.0s - 12.0s : EXTRACT (espresso extraction under pressure)

Fs = 100;              % 100 Hz sampling rate
dt = 1 / Fs;           % 0.01 seconds step
t = (0:dt:13.0)';      % 1301 sample steps (covers past 12.0s stop time)
N = length(t);

accZ = zeros(N, 1);
accY = zeros(N, 1);
accX = zeros(N, 1);

fprintf('Synthesizing 12-second vibration cycle (%d samples at 100 Hz)...\n', N);

for i = 1:N
    cur_t = t(i);
    if cur_t < 3.0
        % IDLE: 9.8 m/s^2 on Z, very low ambient noise on X/Y
        accZ(i) = 9.8 + 0.05 * randn();
        accY(i) = 0.0 + 0.05 * randn();
        accX(i) = 0.0 + 0.05 * randn();
    elseif cur_t < 6.0
        % GRIND: Loud wideband stochastic vibration
        accZ(i) = 9.8 + 8.0 * randn();
        accY(i) = 0.0 + 6.0 * randn();
        accX(i) = 0.0 + 5.0 * randn();
    elseif cur_t < 9.0
        % PUMP: Strong 50 Hz harmonic motor hum
        accZ(i) = 9.8 + 2.5 * sin(2 * pi * 50 * cur_t) + 0.3 * randn();
        accY(i) = 1.8 * cos(2 * pi * 50 * cur_t) + 0.2 * randn();
        accX(i) = 1.2 * sin(2 * pi * 25 * cur_t) + 0.2 * randn();
    else
        % EXTRACT: Steady water infusion under pressure (moderate 50 Hz + flow noise)
        accZ(i) = 9.8 + 1.2 * sin(2 * pi * 50 * cur_t) + 0.4 * randn();
        accY(i) = 0.8 * cos(2 * pi * 50 * cur_t) + 0.3 * randn();
        accX(i) = 0.6 * sin(2 * pi * 25 * cur_t) + 0.3 * randn();
    end
end

% Simulink 'From Workspace' block expects [time, signal_matrix]
vibration_input = [t, accZ, accY, accX];
assignin('base', 'vibration_input', vibration_input);

% -------------------------------------------------------------------------
% 3. Execute Simulink Simulation
% -------------------------------------------------------------------------
fprintf('Running Simulink model: coffee_machine_sim.slx ...\n');
simOut = sim('coffee_machine_sim', 'StopTime', '12.0', 'ReturnWorkspaceOutputs', 'on');
fprintf('Simulation completed successfully!\n\n');

% -------------------------------------------------------------------------
% 4. Extract and Parse Logged Signals
% -------------------------------------------------------------------------
% Classes: 1 = extract, 2 = grind, 3 = idle, 4 = pump
classNames = {'extract', 'grind', 'idle', 'pump'};

% Extract logged signals from yout dataset (element 1 = stage ID, element 2 = probabilities)
stageIdSig = simOut.yout{1};
probsSig   = simOut.yout{2};

sim_t       = stageIdSig.Values.Time;
sim_stageId = squeeze(stageIdSig.Values.Data);
sim_probs   = squeeze(probsSig.Values.Data);

% Ensure sim_stageId is a column vector of length N
sim_stageId = sim_stageId(:);

% Ensure sim_probs has dimensions [N x 4]
if size(sim_probs, 1) ~= length(sim_t) && size(sim_probs, 2) == length(sim_t)
    sim_probs = sim_probs';
end

% -------------------------------------------------------------------------
% 5. Print Stage Progression Summary
% -------------------------------------------------------------------------
fprintf('-----------------------------------------------------------------\n');
fprintf(' Time Interval | True State | Dominant Predicted State | Confidence \n');
fprintf('-----------------------------------------------------------------\n');

time_windows = [
    0.0, 3.0, 3;  % IDLE
    3.0, 6.0, 2;  % GRIND
    6.0, 9.0, 4;  % PUMP
    9.0, 12.0, 1  % EXTRACT
];

for w = 1:size(time_windows, 1)
    t_start = time_windows(w, 1);
    t_end   = time_windows(w, 2);
    true_id = time_windows(w, 3);
    
    % Evaluate after the circular buffer has filled (> 1 second into state)
    eval_mask = (sim_t >= (t_start + 1.2)) & (sim_t <= (t_end - 0.1));
    if any(eval_mask)
        pred_ids = round(sim_stageId(eval_mask));
        dominant_id = mode(pred_ids);
        if dominant_id >= 1 && dominant_id <= 4
            pred_name = classNames{dominant_id};
            avg_conf = mean(sim_probs(eval_mask, dominant_id));
        else
            pred_name = 'unknown';
            avg_conf = 0;
        end
    else
        pred_name = 'warmup';
        avg_conf = 1.0;
    end
    
    true_name = classNames{true_id};
    fprintf(' %4.1fs - %4.1fs | %-10s | %-24s | %5.1f%%\n', ...
        t_start, t_end, upper(true_name), upper(pred_name), avg_conf * 100);
end
fprintf('-----------------------------------------------------------------\n\n');

% -------------------------------------------------------------------------
% 6. Plot Simulation Results & Save Figure
% -------------------------------------------------------------------------
fig = figure('Name', 'Edge Impulse Simulink Coffee Machine Simulation', ...
             'Position', [100, 100, 1100, 800], 'Visible', 'off');

% Subplot 1: Continuous 3-Axis Raw Vibration
subplot(3, 1, 1);
plot(t, accZ, 'r', 'DisplayName', 'accZ (Vertical/Gravity)'); hold on;
plot(t, accY, 'g', 'DisplayName', 'accY (Lateral)');
plot(t, accX, 'b', 'DisplayName', 'accX (Front/Back)');
xline(3, '--k', 'GRIND Start', 'LabelVerticalAlignment', 'bottom');
xline(6, '--k', 'PUMP Start',  'LabelVerticalAlignment', 'bottom');
xline(9, '--k', 'EXTRACT Start', 'LabelVerticalAlignment', 'bottom');
grid on;
title('Simulink Input: Continuous 3-Axis Vibration Sensor Stream [100 Hz]');
xlabel('Simulation Time (seconds)');
ylabel('Acceleration (m/s^2)');
legend('Location', 'northeast');
xlim([0, 12]);

% Subplot 2: Real-Time Edge Impulse Stage Classification
subplot(3, 1, 2);
stairs(sim_t, sim_stageId, 'LineWidth', 2.0, 'Color', [0.1, 0.4, 0.8]); hold on;
yline(1, ':k', 'Extract');
yline(2, ':k', 'Grind');
yline(3, ':k', 'Idle');
yline(4, ':k', 'Pump');
xline(3, '--k');
xline(6, '--k');
xline(9, '--k');
grid on;
title('Simulink Output: Edge Impulse S-Function Predicted Stage ID');
xlabel('Simulation Time (seconds)');
ylabel('Predicted Class');
yticks([1, 2, 3, 4]);
yticklabels({'1: Extract', '2: Grind', '3: Idle', '4: Pump'});
ylim([0.5, 4.5]);
xlim([0, 12]);

% Subplot 3: 4-Class Probability Waves
subplot(3, 1, 3);
colors = [0.85 0.33 0.10; 0.49 0.18 0.56; 0.47 0.67 0.19; 0.30 0.75 0.93];
for c = 1:4
    plot(sim_t, sim_probs(:, c), 'LineWidth', 1.6, 'Color', colors(c, :), ...
         'DisplayName', classNames{c});
    hold on;
end
xline(3, '--k');
xline(6, '--k');
xline(9, '--k');
grid on;
title('Simulink Output: Dynamic Class Probabilities (Sliding Ring Buffer)');
xlabel('Simulation Time (seconds)');
ylabel('Probability (0.0 to 1.0)');
legend('Location', 'northeast');
ylim([-0.05, 1.05]);
xlim([0, 12]);

outPng = fullfile(scriptDir, 'coffee_machine_sim_result.png');
saveas(fig, outPng);
fprintf('Plot successfully saved to: %s\n', outPng);
