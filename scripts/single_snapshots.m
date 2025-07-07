%==========================================================================
% single_snapshots.m
%
% Description:
%   Script to test communication and capture waveform snapshots using the
%   lab_tools MATLAB class. Demonstrates basic waveform setup on a function 
%   generator and automated screenshot capture from an oscilloscope.
%
% Actions Performed:
%   - Configure function generator to output a RAMP waveform at 4 kHz, 2.5 Vpp
%   - Calibrate oscilloscope and capture a screenshot
%   - Set up PEAK and FREQ measurements, capture another screenshot
%   - Switch to SQUARE waveform at 100 Hz, 1 Vpp with averaging, capture final screenshot
%
% Requirements:
%   - lab_tools.m class in the MATLAB path
%   - SCPI-compatible function generator and oscilloscope connected
%
% Author:
%   Sahaj Singh
%
% License:
%   MIT License
%==========================================================================

clc; clear;
addpath(fileparts(fileparts(mfilename('fullpath'))));
lt = lab_tools();

lt.fn_gen_wave = 'RAMP';
lt.fn_gen_freq = 4000;
lt.fn_gen_ampl = 2.5;
lt.scope_calibrate();
lt.scope_capture_screenshot('Image-2.gif');

lt.scope_automeasure('PEAK', 'FREQ');
lt.scope_capture_screenshot('Image-3.gif');

lt.fn_gen_wave = 'SQU';
lt.fn_gen_freq = 100;
lt.fn_gen_ampl = 1;
lt.scope_acquire_average(1024);
lt.scope_capture_screenshot('Image-4.gif');

lt.Close();
