%==========================================================================
% sweep.m
%
% Description:
%   Performs a logarithmic frequency sweep using the lab_tools MATLAB class.
%   The function generator is swept from 1 Hz to 15 MHz, and the oscilloscope
%   measures the peak-to-peak voltages on CH1 and CH2 as well as the phase
%   difference between them.
%
%   All measurements are logged and saved to a timestamped Excel file.
%   If any measurement fails during the sweep, NaNs are recorded for that step.
%
% Output:
%   - Frequency (Hz)
%   - CH1 Peak-to-Peak Voltage (V)
%   - CH2 Peak-to-Peak Voltage (V)
%   - CH2/CH1 Voltage Ratio
%   - Phase Difference (degrees)
%
% Requirements:
%   - lab_tools.m in MATLAB path
%   - Compatible function generator and oscilloscope connected via serial/VISA
%
% Author: Sahaj Singh
% License: MIT
%==========================================================================

clear; clc;
lt = lab_tools();

% Device setup
lt.fn_gen_ampl = 0.2;
lt.fn_gen_wave = "SIN";

% Setup scope
lt.scope_calibrate();

% Generate 50 logarithmically spaced frequencies from 1 Hz to 15 MHz
freq_values = round(logspace(log10(1), log10(1.5e7), 50), 2)';

% Preallocate array for measurements
measurements = zeros(length(freq_values), 5);
measurements(:,1) = freq_values;

for i = 1:length(freq_values)
    freq = freq_values(i);
    fprintf("Running measurement %d / %d: %.2f Hz\n", i, length(freq_values), freq);

    % Set frequency
    lt.fn_gen_freq = freq;

    % Wait for signal to stabilize
    pause(2);

    % Adjust scope
    lt.scope_autoset();
    lt.scope_center_traces();

    % Manual scope x-scale adjustment if needed
    if freq < 5
        lt.scope_writeline('TIM:SCAL 200e-3');
        pause(5);
    elseif freq < 200
        pause(2);
    end
    
    try
        % Measure voltages and phase
        v_ch1 = str2double(lt.scope_writeread('MEAS1:RES?PEAK'));
        pause(0.5)
        v_ch2 = str2double(lt.scope_writeread('MEAS4:RES?PEAK'));
        pause(0.5)
        phase_diff = str2double(lt.scope_writeread('MEAS6:RES?PHAS'));
        pause(0.5)

        % Store results
        measurements(i, 2) = v_ch1;
        measurements(i, 3) = v_ch2;
        measurements(i, 4) = v_ch2 / v_ch1;
        measurements(i, 5) = phase_diff;
    catch err
        fprintf("Measurement failed at %.2f Hz: %s\n", freq, err.message);
        measurements(i, 2:5) = NaN;
    end
end

% Clean up
lt.Close();

% Save results
time_now = string(datetime('now','Format','yyyy-MM-dd''T''HHmmss'));
filename = strcat('Scope_volt_and_phase_measurement_', time_now, '.xls');

T = array2table(measurements, ...
    'VariableNames', {'Frequency_Hz','CH1_Vpp','CH2_Vpp','CH2_div_CH1','Phase_Degrees'});

writetable(T, filename);
fprintf("Results saved to %s\n", filename);

