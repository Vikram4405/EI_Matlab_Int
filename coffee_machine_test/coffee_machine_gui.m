% coffee_machine_gui.m
% Interactive MATLAB Dashboard for Edge Impulse Coffee Machine Vibration Classifier.
%
% Features:
%   - Interactive Toggle Buttons: [IDLE], [GRIND], [PUMP], [EXTRACT]
%   - Live 3-Axis Vibration Oscilloscope (Scrolling 2.0s window)
%   - Real-Time Class Probability Bar Chart
%   - Dynamic Status Indicator Badge with confidence score
%   - Noise Level Slider to test model resilience

function coffee_machine_gui()
    scriptDir = fileparts(mfilename('fullpath'));
    if isempty(scriptDir)
        scriptDir = pwd;
    end
    addpath(scriptDir);

    % Verify MEX binary exists
    if exist('ei_classifier_mex', 'file') ~= 3
        error('ei_classifier_mex not found. Please run build_mex first.');
    end

    % ---------------------------------------------------------------------
    % App State Variables
    % ---------------------------------------------------------------------
    state = struct();
    state.currentStage = 'idle'; % 'idle', 'grind', 'pump', 'extract'
    state.noiseScale   = 1.0;
    state.sampleRate   = 100;     % 100 Hz
    state.windowSize   = 200;     % 200 samples (2.0s)
    state.buffer       = zeros(200, 3);
    state.buffer(:, 1) = 9.8;     % Initialize accZ with gravity
    state.t_internal   = 0;
    state.classNames   = {'extract', 'grind', 'idle', 'pump'};
    state.classColors  = [
        0.85 0.33 0.10;  % extract (amber)
        0.49 0.18 0.56;  % grind (purple)
        0.47 0.67 0.19;  % idle (green)
        0.30 0.75 0.93   % pump (blue)
    ];

    % ---------------------------------------------------------------------
    % UI Layout
    % ---------------------------------------------------------------------
    fig = uifigure('Name', 'Edge Impulse Coffee Machine Classifier Dashboard', ...
                   'Position', [150, 100, 1000, 650], ...
                   'Color', [0.12, 0.14, 0.18]);

    % Title
    uilabel(fig, 'Text', '☕ Edge Impulse Coffee Machine Vibration Classifier', ...
            'Position', [30, 600, 700, 35], ...
            'FontSize', 20, 'FontWeight', 'bold', 'FontColor', [1 1 1]);

    uilabel(fig, 'Text', 'Live TinyML inferencing running inside MATLAB via C++ MEX', ...
            'Position', [32, 578, 500, 20], ...
            'FontSize', 12, 'FontColor', [0.7 0.75 0.8]);

    % Control Panel (Left column)
    ctrlPanel = uipanel(fig, 'Title', 'STAGE CONTROLS (Click to Toggle)', ...
                        'Position', [30, 320, 260, 240], ...
                        'BackgroundColor', [0.16, 0.18, 0.23], ...
                        'ForegroundColor', [0.9, 0.9, 0.9], ...
                        'FontSize', 12, 'FontWeight', 'bold');

    btnIdle = uibutton(ctrlPanel, 'push', 'Text', '💤  IDLE (Resting)', ...
                       'Position', [15, 145, 230, 38], ...
                       'FontSize', 13, 'FontWeight', 'bold', ...
                       'BackgroundColor', [0.2, 0.5, 0.3], 'FontColor', [1 1 1]);

    btnGrind = uibutton(ctrlPanel, 'push', 'Text', '⚙️  GRIND (Beans)', ...
                        'Position', [15, 100, 230, 38], ...
                        'FontSize', 13, 'FontWeight', 'bold', ...
                        'BackgroundColor', [0.3, 0.3, 0.35], 'FontColor', [1 1 1]);

    btnPump = uibutton(ctrlPanel, 'push', 'Text', '💧  PUMP (Water)', ...
                       'Position', [15, 55, 230, 38], ...
                       'FontSize', 13, 'FontWeight', 'bold', ...
                       'BackgroundColor', [0.3, 0.3, 0.35], 'FontColor', [1 1 1]);

    btnExtract = uibutton(ctrlPanel, 'push', 'Text', '☕  EXTRACT (Brew)', ...
                          'Position', [15, 10, 230, 38], ...
                          'FontSize', 13, 'FontWeight', 'bold', ...
                          'BackgroundColor', [0.3, 0.3, 0.35], 'FontColor', [1 1 1]);

    % Status Badge Panel
    badgePanel = uipanel(fig, 'Title', 'PREDICTED STATE & CONFIDENCE', ...
                         'Position', [30, 150, 260, 150], ...
                         'BackgroundColor', [0.16, 0.18, 0.23], ...
                         'ForegroundColor', [0.9, 0.9, 0.9], ...
                         'FontSize', 12, 'FontWeight', 'bold');

    lblDetectedStage = uilabel(badgePanel, 'Text', 'IDLE', ...
                               'Position', [10, 65, 240, 45], ...
                               'FontSize', 26, 'FontWeight', 'bold', ...
                               'FontColor', [0.47, 0.85, 0.3], ...
                               'HorizontalAlignment', 'center');

    lblConfidence = uilabel(badgePanel, 'Text', 'Confidence: 99.8%', ...
                            'Position', [10, 35, 240, 25], ...
                            'FontSize', 14, 'FontColor', [0.9, 0.9, 0.9], ...
                            'HorizontalAlignment', 'center');

    lblLatency = uilabel(badgePanel, 'Text', 'DSP: 1 ms | Inference: 0 ms', ...
                         'Position', [10, 10, 240, 20], ...
                         'FontSize', 11, 'FontColor', [0.6, 0.65, 0.7], ...
                         'HorizontalAlignment', 'center');

    % Noise Slider Panel
    sliderPanel = uipanel(fig, 'Title', 'SENSOR NOISE INJECTION', ...
                          'Position', [30, 30, 260, 100], ...
                          'BackgroundColor', [0.16, 0.18, 0.23], ...
                          'ForegroundColor', [0.9, 0.9, 0.9], ...
                          'FontSize', 11, 'FontWeight', 'bold');

    sldNoise = uislider(sliderPanel, 'Position', [25, 45, 210, 3], ...
                        'Limits', [0.2, 3.0], 'Value', 1.0, ...
                        'FontColor', [0.8 0.8 0.8]);

    % Live Oscilloscope (Middle / Right)
    axOsc = uiaxes(fig, 'Position', [320, 320, 650, 240], ...
                   'Color', [0.08, 0.09, 0.12], ...
                   'XColor', [0.7 0.75 0.8], 'YColor', [0.7 0.75 0.8], ...
                   'GridColor', [0.25 0.28 0.35], 'GridAlpha', 0.6);
    title(axOsc, 'Live 3-Axis Vibration Stream (Scrolling 2.0s Window)', 'Color', [1 1 1]);
    xlabel(axOsc, 'Time Window (seconds)');
    ylabel(axOsc, 'Acceleration (m/s^2)');
    ylim(axOsc, [-15, 30]);
    xlim(axOsc, [0, 2.0]);
    grid(axOsc, 'on');

    t_axis = linspace(0, 2.0, 200)';
    hZ = plot(axOsc, t_axis, state.buffer(:, 1), 'r', 'LineWidth', 1.4, 'DisplayName', 'accZ (Gravity)');
    hold(axOsc, 'on');
    hY = plot(axOsc, t_axis, state.buffer(:, 2), 'g', 'LineWidth', 1.2, 'DisplayName', 'accY (Lateral)');
    hX = plot(axOsc, t_axis, state.buffer(:, 3), 'b', 'LineWidth', 1.2, 'DisplayName', 'accX (Front)');
    legend(axOsc, 'Location', 'northeast', 'TextColor', [0.9 0.9 0.9], 'Color', [0.15 0.17 0.22]);

    % Probability Bar Chart
    axBar = uiaxes(fig, 'Position', [320, 40, 650, 240], ...
                   'Color', [0.08, 0.09, 0.12], ...
                   'XColor', [0.7 0.75 0.8], 'YColor', [0.7 0.75 0.8], ...
                   'GridColor', [0.25 0.28 0.35], 'GridAlpha', 0.6);
    title(axBar, 'Real-Time Edge Impulse Class Probabilities', 'Color', [1 1 1]);
    ylabel(axBar, 'Probability (0.0 to 1.0)');
    ylim(axBar, [0, 1.05]);
    grid(axBar, 'on');

    hBar = bar(axBar, categorical(state.classNames), [0.0, 0.0, 1.0, 0.0], 'FaceColor', 'flat');
    hBar.CData = state.classColors;

    % ---------------------------------------------------------------------
    % Callbacks for Stage Selection Buttons
    % ---------------------------------------------------------------------
    function setStage(newStage)
        state.currentStage = newStage;
        % Reset button colors
        btnIdle.BackgroundColor    = [0.3, 0.3, 0.35];
        btnGrind.BackgroundColor   = [0.3, 0.3, 0.35];
        btnPump.BackgroundColor    = [0.3, 0.3, 0.35];
        btnExtract.BackgroundColor = [0.3, 0.3, 0.35];
        
        switch newStage
            case 'idle'
                btnIdle.BackgroundColor = [0.2, 0.5, 0.3];
            case 'grind'
                btnGrind.BackgroundColor = [0.6, 0.2, 0.2];
            case 'pump'
                btnPump.BackgroundColor = [0.2, 0.4, 0.7];
            case 'extract'
                btnExtract.BackgroundColor = [0.7, 0.45, 0.15];
        end
    end

    btnIdle.ButtonPushedFcn    = @(~, ~) setStage('idle');
    btnGrind.ButtonPushedFcn   = @(~, ~) setStage('grind');
    btnPump.ButtonPushedFcn    = @(~, ~) setStage('pump');
    btnExtract.ButtonPushedFcn = @(~, ~) setStage('extract');

    % ---------------------------------------------------------------------
    % Live Update Loop via MATLAB Timer (10 Hz = 100 ms interval)
    % ---------------------------------------------------------------------
    stepSamples = 10; % 10 samples per 100 ms tick = 100 Hz sampling rate
    dt = 1 / state.sampleRate;

    updateTimer = timer('ExecutionMode', 'fixedRate', 'Period', 0.1, ...
                        'TimerFcn', @onTimerTick);

    function onTimerTick(~, ~)
        if ~isvalid(fig)
            stop(updateTimer);
            delete(updateTimer);
            return;
        end

        state.noiseScale = sldNoise.Value;

        % Synthesize 10 new samples based on active stage
        newChunk = zeros(stepSamples, 3);
        for s = 1:stepSamples
            state.t_internal = state.t_internal + dt;
            ct = state.t_internal;
            ns = state.noiseScale;

            switch state.currentStage
                case 'idle'
                    newChunk(s, 1) = 9.8 + (0.05 * ns) * randn();
                    newChunk(s, 2) = 0.0 + (0.05 * ns) * randn();
                    newChunk(s, 3) = 0.0 + (0.05 * ns) * randn();
                case 'grind'
                    newChunk(s, 1) = 9.8 + (8.0 * ns) * randn();
                    newChunk(s, 2) = 0.0 + (6.0 * ns) * randn();
                    newChunk(s, 3) = 0.0 + (5.0 * ns) * randn();
                case 'pump'
                    newChunk(s, 1) = 9.8 + 2.5 * sin(2*pi*50*ct) + (0.3 * ns) * randn();
                    newChunk(s, 2) = 1.8 * cos(2*pi*50*ct) + (0.2 * ns) * randn();
                    newChunk(s, 3) = 1.2 * sin(2*pi*25*ct) + (0.2 * ns) * randn();
                case 'extract'
                    newChunk(s, 1) = 9.8 + 1.2 * sin(2*pi*50*ct) + (0.4 * ns) * randn();
                    newChunk(s, 2) = 0.8 * cos(2*pi*50*ct) + (0.3 * ns) * randn();
                    newChunk(s, 3) = 0.6 * sin(2*pi*25*ct) + (0.3 * ns) * randn();
            end
        end

        % Roll buffer forward: drop oldest 10, append newest 10
        state.buffer = [state.buffer(stepSamples+1:end, :); newChunk];

        % Run Edge Impulse MEX Inference on full 200x3 rolling window!
        res = ei_classifier_mex(state.buffer);

        % Update Oscilloscope traces
        hZ.YData = state.buffer(:, 1);
        hY.YData = state.buffer(:, 2);
        hX.YData = state.buffer(:, 3);

        % Update Probability Bar Chart
        hBar.YData = res.scores;

        % Update Status Badge & Labels
        predStage = upper(res.predicted_label);
        bestConf  = max(res.scores) * 100;
        lblDetectedStage.Text = predStage;
        lblConfidence.Text = sprintf('Confidence: %5.1f%%', bestConf);
        lblLatency.Text = sprintf('DSP: %.1f ms | Inference: %.1f ms', ...
                                  res.timing_dsp_ms, res.timing_infer_ms);

        % Dynamic color coding for badge
        switch lower(res.predicted_label)
            case 'idle'
                lblDetectedStage.FontColor = [0.47, 0.85, 0.3];  % Green
            case 'grind'
                lblDetectedStage.FontColor = [0.95, 0.3, 0.3];   % Red
            case 'pump'
                lblDetectedStage.FontColor = [0.3, 0.75, 0.95];  % Blue
            case 'extract'
                lblDetectedStage.FontColor = [0.95, 0.65, 0.2];  % Amber
        end
    end

    % Clean up timer when figure is closed
    fig.CloseRequestFcn = @(~, ~) closeDashboard(fig, updateTimer);
    start(updateTimer);
end

function closeDashboard(fig, tmr)
    if isvalid(tmr)
        stop(tmr);
        delete(tmr);
    end
    delete(fig);
end
