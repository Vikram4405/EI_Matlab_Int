% test_coffee_classifier.m
% Tests the compiled Edge Impulse Coffee Machine Vibration Classifier MEX function.

fprintf('=== Testing Edge Impulse Coffee Machine Vibration Classifier ===\n\n');

% Verify the compiled MEX file exists
if exist('ei_classifier_mex', 'file') ~= 3
    error('ei_classifier_mex MEX file not found. Please run "build_mex" first.');
end

% -------------------------------------------------------------------------
% 1. Model Configuration
% -------------------------------------------------------------------------
sample_rate = 100;         % 100 Hz (10 ms interval)
duration_sec = 2.0;        % 2.0 seconds window
num_samples = 200;         % 200 time steps
num_axes = 3;              % 3 axes: [accZ, accY, accX]

t = linspace(0, duration_sec, num_samples)';

fprintf('Generating synthetic vibration profiles for testing:\n');
fprintf('  1. IDLE  : Minor static sensor noise + gravity\n');
fprintf('  2. PUMP  : 50 Hz harmonic vibration\n');
fprintf('  3. GRIND : High-energy wideband vibration\n\n');

% -------------------------------------------------------------------------
% 2. Generate Synthetic Test Signals (200 x 3 matrix)
% -------------------------------------------------------------------------

% Scenario A: IDLE (Machine resting, gravity ~9.8 on Z, subtle noise on X/Y)
idle_Z = 9.8 + 0.05 * randn(num_samples, 1);
idle_Y = 0.0 + 0.05 * randn(num_samples, 1);
idle_X = 0.0 + 0.05 * randn(num_samples, 1);
signal_idle = [idle_Z, idle_Y, idle_X];

% Scenario B: PUMP (Water pump humming at 50 Hz with harmonics)
pump_Z = 9.8 + 2.5 * sin(2 * pi * 50 * t) + 0.3 * randn(num_samples, 1);
pump_Y = 1.8 * cos(2 * pi * 50 * t) + 0.2 * randn(num_samples, 1);
pump_X = 1.2 * sin(2 * pi * 25 * t) + 0.2 * randn(num_samples, 1);
signal_pump = [pump_Z, pump_Y, pump_X];

% Scenario C: GRIND (Violent high-frequency bean crushing)
grind_Z = 9.8 + 8.0 * randn(num_samples, 1);
grind_Y = 6.0 * randn(num_samples, 1);
grind_X = 5.0 * randn(num_samples, 1);
signal_grind = [grind_Z, grind_Y, grind_X];

test_cases = {
    'Simulated IDLE State',  signal_idle;
    'Simulated PUMP State',  signal_pump;
    'Simulated GRIND State', signal_grind
};

% -------------------------------------------------------------------------
% 3. Run Inference on Test Cases
% -------------------------------------------------------------------------
figure('Name', 'Edge Impulse Coffee Stage Classifier', 'Position', [100, 100, 1000, 600]);

for k = 1:size(test_cases, 1)
    case_name = test_cases{k, 1};
    sig_data  = test_cases{k, 2};
    
    % Run MEX Inference!
    res = ei_classifier_mex(sig_data);
    
    fprintf('--------------------------------------------------\n');
    fprintf('Test Case [%d]: %s\n', k, case_name);
    fprintf('Predicted Stage: >> %s <<\n', upper(res.predicted_label));
    fprintf('Confidence Scores:\n');
    for c = 1:length(res.labels)
        bar_len = round(res.scores(c) * 20);
        bar_str = repmat('#', 1, bar_len);
        fprintf('  %-8s: %6.2f%%  |%s\n', res.labels{c}, res.scores(c) * 100, bar_str);
    end
    fprintf('Timings: DSP = %.2f ms | Inference = %.2f ms\n', res.timing_dsp_ms, res.timing_infer_ms);
    
    % Plot Vibration & Bar Chart
    subplot(3, 2, (k-1)*2 + 1);
    plot(t, sig_data(:, 1), 'r', t, sig_data(:, 2), 'g', t, sig_data(:, 3), 'b');
    title([case_name ' - Raw Vibration']);
    xlabel('Time (s)'); ylabel('m/s^2');
    legend('accZ', 'accY', 'accX', 'Location', 'northeast');
    grid on;
    
    subplot(3, 2, (k-1)*2 + 2);
    bar(res.scores, 'FaceColor', [0.2 0.6 0.8]);
    set(gca, 'XTickLabel', res.labels);
    ylim([0 1]);
    title(['Predictions: ' res.predicted_label ' (' num2str(max(res.scores)*100, '%.1f') '%)']);
    ylabel('Confidence');
    grid on;
end

fprintf('\n=== All Tests Completed Successfully ===\n');
