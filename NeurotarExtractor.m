classdef NeurotarExtractor < handle
    
    % Properties we are interested as output
    properties (Access = public)
        behavior            struct
        behavior_raw        struct
    end
    
    properties (Access = private)
        options
        tdms_filename
    end
    
    % Initializing methods
    methods (Access = public)
        
        function obj = NeurotarExtractor(tdms_filename, varargin)
            
            obj.options = inputParser;
            addParameter(obj.options, 'IMAGING_METHOD','WideField')
            addParameter(obj.options, 'SAMPLING_PERIOD', 100) % changed from "samplingWindow", default 100 (msec?)
            addParameter(obj.options, 'OFF_TIME', 0)
            addParameter(obj.options, 'VERSION', 'New')
            parse(obj.options,varargin{:})
            
            if nargin == 0
                tdms_filename = obj.getTDMSFilename();
            end
            
<<<<<<< Updated upstream
            obj.tdms_filename = obj.checkTDMSFilename(tdms_filename); % added to allow flexibility for either filenames or not
            obj.readTDMS();
            
            obj.resampling();
            obj.movingDetector();
=======
            obj.readFile();
             
%             obj.resampling();
%             obj.movingDetector();

>>>>>>> Stashed changes
        end
        
    end
    
    % Convert from .tdms methods. TDMS functions need to be in path
    methods (Access = private)
        
        function out = checkTDMSFilename(obj, tdms_filename)
            
            [~, ~, ext] = fileparts(tdms_filename);
            if strcmp(ext, '.tdms')
                out = tdms_filename;
                return % is a proper tdms file
            else
                obj.enforceSessionName(tdms_filename); % confirm that it's a session name, not some other junk
                out = strcat(tdms_filename, '.tdms'); % properly convert from session name into tdms filename
            end
            
        end
        
        function enforceSessionName(obj, tdms_filename) % used to be called checkIDName
            % think about this section...
            
            if isempty(regexp(tdms_filename,...
                    '[A-Z][A-Z][A-Z][0-9][0-9][0-9]_[0-9][0-9][0-1][0-9][0-3][0-9]', 'once')) % enforce format
                error('Session ID incorrect, should be in the format: NNN###_YYMMDD, examples: SAM000_210910');
            end
  
        end
        
        function tdms_filename = getTDMSFilename(obj)
            
            fprintf('Choose your folder containing the .tdms file: \n');
            folder = uigetdir();
            
            tdms_location = dir(strcat(folder, filesep, '*.tdms'));
            if numel(tdms_location) > 1
                warning('Multiple TDMS files found, choose your TDMS file: ')
                [tdms_fn, tdms_pn] = uigetfile('*.tdms');
                tdms_filename = strcat(tdms_pn, filesep, tdms_fn);
            else
                tdms_filename = strcat(tdms_location.folder, filesep, tdms_location.name);
            end
            
        end
        
        function readTDMS(obj)
            
            behavior_file = TDMS_readTDMSFile(obj.tdms_filename);
           
            behavior_data = behavior_file.data;
            obj.behavior_raw = struct;
            
            switch obj.options.Results.VERSION
                case 'New'
                    obj.behavior_raw.R = behavior_data{8}';
                    obj.behavior_raw.phi = behavior_data{9}';
                    obj.behavior_raw.alpha = behavior_data{10}';
                    obj.behavior_raw.X = 1.25 * behavior_data{11}';
                    obj.behavior_raw.Y = 1.25 * -behavior_data{12}';
                    obj.behavior_raw.theta = behavior_data{13}';
                    obj.behavior_raw.beta = behavior_data{14}';
                    obj.behavior_raw.w = behavior_data{15}';
                    obj.behavior_raw.speed = behavior_data{16}';
                    obj.behavior_raw.zones = behavior_data{17}';
                    obj.behavior_raw.time = behavior_data{5};
                    obj.behavior_raw.time = obj.behavior_raw.time - ...
                        obj.behavior_raw.time(1);
                    
                case 'Old'
                    
                    obj.behavior_raw.R = behavior_data{10}';
                    obj.behavior_raw.phi = behavior_data{11}';
                    obj.behavior_raw.alpha = behavior_data{12}';
                    obj.behavior_raw.X = behavior_data{13}';
                    obj.behavior_raw.Y = -behavior_data{14}';
                    obj.behavior_raw.w = behavior_data{15}';
                    obj.behavior_raw.speed = behavior_data{16}';
                    obj.behavior_raw.zones = behavior_data{17}';
                    
                otherwise
                    answer = questdlg('Which NeuroTar version are you using?',...
                        'NeuroTar Version','Old', 'New', 'New');
                    
                    obj.options.Results.VERSION = answer;
                    readTMDS(obj);
                    
            end
            
        end
        
    end
    
    % Processing methods
    methods (Access = private)
        
        function resampling(obj)
            
            % This function takes the Neurotar sampling rate (typically 20ms or
            % 13ms) and resamples it taking into account the sampling rate of
            % the microscope and the exposition time. It does so by taking the
            % average when the window is open.
            
            obj.behavior = struct;
            
            microscope_rate = obj.options.Results.SAMPLING_PERIOD;
            off_time = obj.options.Results.OFF_TIME;
            microscope_frames = 0:microscope_rate:obj.behavior_raw.time(end);
            
            fn = fieldnames(obj.behavior_raw);
            
            for i = 2:length(microscope_frames)
                ind = obj.behavior_raw.time > microscope_frames(i-1) + off_time ...
                    & obj.behavior_raw.time < microscope_frames(i);
                
                for j = 1:numel(fn)
                    
                    obj.behavior.(fn{j})(i-1) = mean(obj.behavior_raw.(fn{j})(ind));
                    
                end
                
            end
            
        end
        
        function movingDetector(obj)
            
            % This function detects when the mouse is running and when is not
            % by detecting the moving bouts.
            %
            % Adapted from Will
            
            speed = obj.behavior.speed;
            speed = smooth(speed, 200, 'moving')';
            
            speed(speed>200) = 200;
            speed_thresh = 8;
            bout_thresh = 10;
            
            moving_time = speed > speed_thresh;
            moving_time = [false, moving_time, false];
            bout_start = strfind(moving_time, [false true]) + 1;
            bout_end = strfind(moving_time, [true false]);
            
            for i = 1:length(bout_end)
                
                if bout_end(i)-bout_start(i) < bout_thresh
                    moving_time(bout_start(i):bout_end(i)) = false;
                elseif bout_start(i)>10
                    moving_time(bout_start(i)-10:bout_end(i)) = true;
                end
                
            end
            
            obj.behavior.moving_time = moving_time(2:end-1);
            
        end
        
    end
    
    % Statistic visualization
    methods (Access = private)
        
    end
    
    % Saving methods
    methods
        
    end
    
    
end



