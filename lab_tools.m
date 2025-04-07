%==========================================================================
% lab_tools.m
%
% Description:
%   MATLAB class for interfacing with laboratory bench equipment such as
%   function generators and oscilloscopes using serial and VISA protocols.
%   Supports waveform configuration, scope automation, data acquisition,
%   and screenshot capture.
%
% Author:
%   Sahaj Singh
%
% Repository:
%   https://github.com/sahajcodes/lab_tools
%
% Requirements:
%   - MATLAB (R2021a or later recommended)
%   - Instrument Control Toolbox
%
% Usage:
%   Refer to the example scripts in the 'scripts/' directory.
%
% License:
%   MIT License
%==========================================================================

classdef lab_tools < handle
    properties
        fn_gen_ampl = 1.0     % volts
        fn_gen_freq = 1000    % Hz
        fn_gen_wave = "SIN"   % Default waveform
    end

    properties (Access=private)
        % Device Ports
        fn_gen_port
        scope_port
        % Device Objects
        fn_gen_object
        scope_object
        % Class
        initialized = false;
        latest_fn_gen_mode = true; %Set to latest Fn Gen by Default
        afg2225_valid_waves = ["SIN", "RAMP", "SQU"];
        instek_valid_waves = ["SIN", "TRI", "SQR"];
        scope_valid_automeasure_types = [
            "FREQ", "PER", "PEAK", "UPE", "LPE", "PPC", "NPC", "REC", ...
            "FEC", "HIGH", "LOW", "AMPL", "CRES", "MEAN", "RMS", "RTIM", ...
            "FTIM", "PDCY", "NDCY", "PPW", "NPW", "CYCM", "CYCR", "STDD", ...
            "TFR", "TPER", "DEL", "PHAS", "BWID", "POV", "NOV"
            ];
        scope_valid_averages = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024];
    end

    methods(Static)
        function list_devices()
            ports = serialportlist("available");
            if isempty(ports)
                fprintf("No available serial ports found.\n");
            else
                fprintf("Available serial ports: %s\n", strjoin(ports, ' '));
            end
            try
                connected = visadevlist;
                if ~isempty(connected)
                    disp("Connected VISA devices:");
                    disp(connected);
                else
                    disp("No VISA devices found.");
                end
            catch
                warning("Unable to fetch visadev list. Ensure Instrument Control Toolbox is available.");
            end
        end
    end

    methods (Access = private)
        function response = trySerial(~, port, baudrate, cmd)
            s = serialport(port, baudrate, 'Timeout', 0.5); % shorter timeout
            pause(0.2); % let device settle
            flush(s);
            writeline(s, cmd);
            pause(0.2); % wait for response

            if s.NumBytesAvailable > 0
                response = readline(s);
            else
                response = "<no response>";
            end

            delete(s);
        end
    end

    methods
        function obj = lab_tools()
            if obj.initialized
                return
            end
            
            delete(instrfind);
            obj.find_com_ports();

            try
                if isnumeric(obj.fn_gen_port)
                    obj.fn_gen_port = string(obj.fn_gen_port);
                end
                obj.fn_gen_object = serialport(obj.fn_gen_port, 19200);
            catch err
                fprintf('Failed to connect to function generator:\n%s\n', err.message);
                lab_tools.list_devices();
            end

            try
                com_idx = str2double(extractBetween(obj.scope_port, 4, 4));
                obj.scope_object = visa('rs', sprintf('ASRL%1d::INSTR', com_idx));
                fopen(obj.scope_object);
            catch err
                obj.reset_objects();
                fprintf('Failed to connect to scope:\n%s\n', err.message);
                lab_tools.list_devices();
            end

            obj.initialized = true;

            if ~isempty(obj.fn_gen_object)
                fprintf('Opened Function Generator: %s\n', obj.fn_gen_writeread('*IDN?'));
            else
                warning('Function Generator not detected. Some features will be unavailable.');
            end
            if ~isempty(obj.scope_object)
                fprintf('Opened Scope: %s\n', obj.scope_writeread('*IDN?'));
            else
                warning('Oscilloscope not detected. Some features will be unavailable.');
            end

            obj.reset();
            pause(1);
        end

        function find_com_ports(obj)
            % Get all serial ports
            all_ports = serialportlist("all");
            
            % Loop through and close any open serial ports
            for i = 1:length(all_ports)
                try
                    portObj = serialport(all_ports(i), 9600);
                    portObj.delete;  % Close the port
                catch
                    % Handle error if port is already closed or not open
                end
            end

            % Filter out irrelevant ports
            filtered_ports = all_ports(~contains(all_ports, ["Bluetooth", "debug", "tty."]));

            disp("Filtered serial ports:");
            disp(filtered_ports);

            if numel(filtered_ports) < 1
                error('No usable serial ports found. Check connections or try again.');
            end

            % Try each remaining port and identify device
            for i = 1:length(filtered_ports)
                port = filtered_ports(i);
                fprintf("\nTrying port: %s\n", port);

                try
                    idn = obj.trySerial(port, 19200, "*IDN?");
                    fprintf("Device Response from %s:\n%s\n", port, idn);

                    if contains(idn, 'Rohde&Schwarz')
                        obj.scope_port = port;
                    elseif contains(idn, 'GW, GFG') || contains(idn, 'Function Generator')
                        obj.fn_gen_port = port;
                        obj.latest_fn_gen_mode = false;
                    elseif contains(idn, 'AFG-2225')
                        obj.fn_gen_port = port;
                    end
                catch err
                    fprintf("Error with port %s:\n%s\n", port, err.message);
                end
            end
        end

        function reset(obj)
            if ~isempty(obj.fn_gen_object)
                obj.fn_gen_writeline('*RST');
            end
            if ~isempty(obj.scope_object)
                obj.scope_writeline('*RST');
            end
        end

        function delete_fn_gen_object(obj)
            if ~isempty(obj.fn_gen_object)
                obj.fn_gen_object = [];
            end
        end

        function delete_scope_object(obj)
            if ~isempty(obj.scope_object)
                obj.scope_object = [];
            end
        end

        function reset_objects(obj)
            obj.delete_fn_gen_object();
            obj.delete_scope_object();
            obj.initialized = false;
        end

        function is_valid = fn_obj_check(obj)
            if isempty(obj.fn_gen_object)
                warning("Function generator not connected. Skipping command.");
                is_valid = false;
            else
                is_valid = true;
            end
        end

        function is_valid = scope_obj_check(obj)
            if isempty(obj.scope_object)
                warning("Scope not connected. Skipping command.");
                is_valid = false;
            else
                is_valid = true;
            end
        end

        function Close(obj)
            try
                obj.reset();
                obj.reset_objects();
            catch err
                fprintf('Error closing: %s\n', err.message);
            end
        end

        function delete(obj)
            obj.Close();
        end

        %%%%%%%%%%%% FN_GEN

        function set.fn_gen_ampl(obj, ampl)
            if ~fn_obj_check(obj)
                return;
            end
            if obj.latest_fn_gen_mode
                obj.fn_gen_writeline(sprintf('SOUR1:VOLT:UNIT VPP', ampl));
                obj.fn_gen_writeline(sprintf('SOUR1:AMP %.3f', ampl));
            else
                obj.fn_gen_writeline(sprintf('AMPL:VOLT %.3f', ampl));
            end
        end

        function ampl = get.fn_gen_ampl(obj)
            if ~fn_obj_check(obj)
                return;
            end

            if obj.latest_fn_gen_mode
                ampl = str2double(obj.fn_gen_writeread('SOUR1:AMP?'));
            else
                ampl = str2double(obj.fn_gen_writeread('AMPL:VOLT ?'));
            end
        end

        function set.fn_gen_freq(obj, freq)
            if ~fn_obj_check(obj)
                return;
            end

            if obj.latest_fn_gen_mode
                obj.fn_gen_writeline(sprintf('SOUR1:FREQ %dHz', freq));
            else
                obj.fn_gen_writeline(sprintf('FREQ %d', freq));
            end
        end

        function freq = get.fn_gen_freq(obj)
            if ~fn_obj_check(obj)
                return;
            end

            if obj.latest_fn_gen_mode
                freq = str2double(obj.fn_gen_writeread('SOUR1:FREQ?'));
            else
                freq = str2double(obj.fn_gen_writeread('FREQ ?'));
            end
        end

        function set.fn_gen_wave(obj, wave)
            if ~fn_obj_check(obj)
                return;
            end

            if obj.latest_fn_gen_mode
                if ~sum(contains(obj.afg2225_valid_waves, wave))
                    fprintf(sprintf('Invalid wave, valid options: %s\n', sprintf('%s ', obj.afg2225_valid_waves)));
                    return
                end
                obj.fn_gen_writeline(sprintf('SOUR1:APPL:%s', wave));
            else
                if ~sum(contains(obj.instek_valid_waves, wave))
                    fprintf(sprintf('Invalid wave, valid options: %s\n', sprintf('%s ', obj.instek_valid_waves)));
                    return
                end
                idx = find(contains(obj.instek_valid_waves, wave));
                obj.fn_gen_writeline(sprintf('FUNC:WAV %d', idx));
            end
        end

        function wave = get.fn_gen_wave(obj)
            if ~fn_obj_check(obj)
                return;
            end

            if obj.latest_fn_gen_mode
                idx = str2double(obj.fn_gen_writeread('FUNC:WAV ?'));
                wave = obj.afg2225_valid_waves(idx);
            else
                idx = str2double(obj.fn_gen_writeread('FUNC:WAV ?'));
                wave = obj.instek_valid_waves(idx);
            end
        end

        %%%%%%%%%%%% SCOPE

        function scope_calibrate(obj)
            if ~scope_obj_check(obj)
                return;
            end

            obj.scope_writeline('CHAN1:STAT ON');
            obj.scope_writeline('CHAN2:STAT ON');

            obj.scope_writeline('PROB1:SET:ATT:MAN 10');
            obj.scope_writeline('PROB2:SET:ATT:MAN 10');

            obj.scope_writeline('AUT');
        end

        function scope_autoset(obj)
            if ~scope_obj_check(obj)
                return;
            end

            obj.scope_writeline('AUT');
        end

        function scope_set_xscale(obj)
            if ~scope_obj_check(obj)
                return;
            end

            period = 1/obj.fn_gen_freq;
            obj.scope_writeline(sprintf('TIM:SCAL %.3E', 3*period/12));
        end

        function scope_automeasure(obj, key1, key2)
            if ~scope_obj_check(obj)
                return;
            end

            if ~sum(contains(obj.scope_valid_automeasure_types, key1)) || ~sum(contains(obj.scope_valid_automeasure_types, key2))
                fprintf(sprintf('Invalid automeasure key, valid options: %s\n', sprintf('%s ', obj.scope_valid_automeasure_types)));
                return
            end

            obj.scope_writeline('MEAS1 ON');
            obj.scope_writeline('MEAS2 ON');
            obj.scope_writeline('MEAS3 ON');
            obj.scope_writeline('MEAS4 ON');

            obj.scope_writeline('MEAS1:SOUR CH1');
            obj.scope_writeline('MEAS2:SOUR CH1');
            obj.scope_writeline('MEAS3:SOUR CH2');
            obj.scope_writeline('MEAS4:SOUR CH2');

            obj.scope_writeline(sprintf('MEAS1:MAIN %d', key1));
            obj.scope_writeline(sprintf('MEAS2:MAIN %d', key2));
            obj.scope_writeline(sprintf('MEAS3:MAIN %d', key1));
            obj.scope_writeline(sprintf('MEAS4:MAIN %d', key2));
        end

        function scope_acquire_average(obj, count)
            if ~scope_obj_check(obj)
                return;
            end

            if ~sum(ismember(count, obj.scope_valid_averages))
                fprintf('Count must be power of 2 in the range 2->1024\n');
            end
            obj.scope_writeline('ACQ:TYPE Refresh');
            obj.scope_writeline('ACQ:TYPE Average');
            obj.scope_writeline(sprintf('ACQ:AVER:COUNT %d', count));

            freq = obj.fn_gen_freq;
            delay = count/freq;
            pause(delay);
        end

        function scope_acquire_refresh(obj)
            if ~scope_obj_check(obj)
                return;
            end

            obj.scope_writeline('ACQ:TYPE Refresh');
        end

        function scope_center_traces(obj)
            if ~scope_obj_check(obj)
                return;
            end

            obj.scope_writeline('CHAN1:POS 0');
            obj.scope_writeline('CHAN2:POS 0');
        end

        function scope_capture_screenshot(obj, filename)
            if ~scope_obj_check(obj)
                return;
            end
            
            [datapath, basename, ext] = fileparts(filename);
            if ~strcmp(lower(ext), '.gif')
                fprintf('You are being forced to use GIF - set the extension to .gif\n');
                return
            end
            obj.scope_writeline('MMEM:DEL ''internal_ss.gif''');
            obj.scope_writeread('*CLS;*OPC?');
            obj.scope_read_errors();
            obj.scope_writeline('HCOP:LANG GIF;:MMEM:NAME ''internal_ss''');
            obj.scope_writeline('HCOP:IMM');
            obj.scope_writeread('*OPC?');
            obj.scope_check_errors();
            obj.scope_writeline('MMEM:DATA? ''internal_ss.gif''');
            try
                img_data = obj.scope_read_image();

                fid = fopen(filename, 'w');
                fwrite(fid, img_data);
                fclose(fid);
                fprintf(sprintf('Saved to file %s\n', filename));
            catch err
                getReport(err)
            end

            % Force return of scope to usable state regardless of success
            % or failure
            flushinput(obj.scope_object);
            obj.scope_object.Terminator = 'LF';
            obj.scope_check_errors();
        end

        function data = scope_read_image(obj)
            obj.scope_object.Terminator = '';
            bl = obj.scope_parse_block_header();

            data = zeros(bl, 1, 'uint8');
            idx = 1;
            c = 0;
            while c < bl
                rem = bl - c;
                if rem >= obj.scope_object.InputBufferSize
                    rem = obj.scope_object.InputBufferSize;
                end
                [data_v, c_v] = fread(obj.scope_object, rem, 'uint8');
                data(idx:idx + c_v - 1) = data_v;
                c = c + c_v;
                idx = idx + c_v;
            end
            if c ~= bl
                throw(MException('Failed to read expected amount of data...\n'));
            end
            obj.scope_object.Terminator = 'LF';
        end

        function bl = scope_parse_block_header(obj)
            hash = fread(obj.scope_object, 1, 'uint8');
            if hash ~= '#'
                throw(MException('No # at start of binary data...\n'));
            end

            bll = str2double(char(fread(obj.scope_object, 1, 'uint8')));
            bl = str2double(char(fread(obj.scope_object, bll, 'uint8')));
        end

        function scope_check_errors(obj)
            errors = obj.scope_read_errors();
            if ~isempty(errors)
                fprintf('Found errors on scope!!\n');
                err_str = strjoin(errors, '\n');
                sprintf(err_str)
            end
        end

        function errors = scope_read_errors(obj)
            errors = {};
            status = str2num(['int32(' obj.scope_writeread('*STB?') ')']);
            if bitand(status, 4) > 0
                while 1
                    error = obj.scope_writeread('SYST:ERR?');
                    if ~contains(lower(error), '"no error"')
                        break
                    end
                    errors{end + 1} = error;
                end
            end
        end

        %%%%%%%%%%%% Other

        function fn_gen_writeline(obj, cmd)
            if ~obj.initialized
                error("lab_tools instance is not initialized. Skipping command.\n");
            end
            if ~fn_obj_check(obj)
                return;
            end
            writeline(obj.fn_gen_object, cmd);
            pause(0.25);
        end

        function result = fn_gen_writeread(obj, cmd)
            if ~obj.initialized
                error("lab_tools instance is not initialized. Skipping command.\n");
            end
            if isempty(obj.fn_gen_object)
                warning("Function generator not connected. Skipping command.");
                result = ""; % or [] or NaN or some default safe value
                return;
            end
            result = writeread(obj.fn_gen_object, cmd);
            pause(0.25);
        end

        function scope_writeline(obj, cmd)
            if ~obj.initialized
                error("lab_tools instance is not initialized. Skipping command.\n");
            end
            if ~scope_obj_check(obj)
                return;
            end
            
            fprintf(obj.scope_object, cmd);
            pause(0.25);
        end

        function result = scope_writeread(obj, cmd)
            if ~obj.initialized
                error("lab_tools instance is not initialized. Skipping command.\n");
            end
            if isempty(obj.scope_object)
                warning("Scope not connected. Skipping command.");
                result = ""; % or [] or NaN or some default safe value
                return;
            end
            result = query(obj.scope_object, cmd);
            pause(0.25);
        end
    end
end
