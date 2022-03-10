classdef NeurotarExtractor < handle
    
    % Properties we are interested as output
    properties (Access = public)
        behavior            struct
        behavior_raw        struct
    end
    
    properties (Access = private)
        FILENAME
        VERSION = 'new'
        OFF_TIME = 0
        SAMPLING_PERIOD = 100
        TDMS_FLAG = true
        FILETYPE
        FIELDS = ["X", "Y", "zones", "time", "speed", "R", "phi", ...
            "alpha", "omega"]
    end
    
    properties (Dependent)
        PARAMETERS
        pose
    end
    
    % Initializing methods
    methods (Access = public)
        
        function obj = NeurotarExtractor(input_file)
            
            if nargin == 0
                obj.getFilename();
            else
                obj.FILENAME = input_file;
            end
            
            
            obj.readFile();
             
%             obj.resampling();
%             obj.movingDetector();

        end
        
    end
         
    methods
        
        function setPropValue(obj, prop_name, prop_value)
            % If more than one property value, prop name and prop value
            % must be column vectors
            eid = 'getPropValue:inputError';
            
            if nargin == 2 
                
                if isstruct(prop_name)
                
                prop_struct = prop_name;
                fn = fieldnames(prop_struct);
                [prop_name, prop_value] = deal(strings([1,length(fn)]));
                
                for i = 1:length(fn)
                    prop_name(i) = fn{i};
                    prop_value(i) = string(prop_struct.(prop_name(i)));
                end
                
                else
                    
                    msg = 'If one input is given, it must be a struct';
                    throwAsCaller(MException(eid, msg));
                end
       
            end
                   
            if ~isstring(prop_name)
                throwAsCaller(MException(eid, 'Prop name must be a string'));
                
            elseif ~isstring(prop_value)
                throwAsCaller(MException(eid, 'Value name must be a string'));
                
            else
                for i = size(prop_name, 2)
                    obj.(prop_name(i)) = prop_value(i);
                end
                
            end
             
        end
             
        function set.VERSION(obj, input)
            
            eid = 'VERSION:inputError';
            msg = 'Only "old" and "new" version names accepted';
            
            if isstring(input)
                input = convertStringsToChars(input);
                
            elseif ~ischar(input)
                throwAsCaller(MException(eid,msg));
            end
            
            if ~ismember(input, {'old', 'new'})
                throwAsCaller(MException(eid,msg))
            else
                obj.VERSION = input;
            end
            
        end
        
        function set.OFF_TIME(obj, input)

            msg = 'OFF_TIME must be a number';
            eid = 'OFF_TIME:inputError';
            
            input = obj.checkPositiveInteger(input, msg, eid);
            obj.OFF_TIME = input;
            
        end
        
        function set.SAMPLING_PERIOD(obj, input)
            
            msg = 'SAMPLING_PERIOD must be a number';
            eid = 'SAMPLING_PERIOD:inputError';
            
            input = obj.checkPositiveInteger(input, msg, eid);
            obj.SAMPLING_PERIOD = input;
            
        end
        
        function set.FILENAME(obj, input)
            
            eid = 'TDMS_FILENAME:inputError';
            msg = 'Input file must be TDMS/XLSX';
            
            if isstring(input)
                input = convertStringsToChars(input);
            end
            
            if ~ischar(input)
                throwAsCaller(MException(eid,msg)) 
            end
            
            [~, ~, ext] = fileparts(input);
            if strcmp(ext, '.tdms') || strcmp(ext, '.xlsx')
                obj.FILENAME = input;
            else 
                throwAsCaller(MException(eid,msg))                        
            end
            
        end
        
        function parameters = get.PARAMETERS(obj)
            
            parameters = struct;
            parameters.VERSION = obj.VERSION;
            parameters.OFF_TIME = obj.OFF_TIME;
            parameters.FILENAME = obj.FILENAME;
            parameters.SAMPLING_PERIOD = obj.SAMPLING_PERIOD;
            
        end
        
        function pose = get.pose(obj)
            
            if ~isempty(obj.behavior)
                pose = [obj.behavior.X; obj.behavior.Y; ...
                        wrapTo360(obj.behavior.alpha - 90)];
            elseif ~isempty(obj.behavior_raw)
                pose = [obj.behavior_raw.X'; obj.behavior_raw.Y'; ...
                        wrapTo360(obj.behavior_raw.alpha' - 90)];
            else
                pose = [];
                disp('Raw file is yet to be read')
            end
                
  
        end
        
    end
    
    methods(Static, Access = private)
        
        function out = checkPositiveInteger(input, msg, eid)
            
            if isstring(input)
                input = str2double(input);
            end
            
            if isnan(input)
                
                throwAsCaller(MException(eid,msg))
                
            elseif input<0 || mod(input,1)
                
                throwAsCaller(MException(eid,msg))   
            else
                out = input;
            end
            
            
        end
        
    end
        
    % Read from TDMS or XLSX files. If TDMS, TDMS functions need to be in path
    methods (Access = private)
        
        function getFilename(obj)
            
            folder = uigetdir([], 'Choose the folder containing the file:');
            
            tdms_files = strcat(folder, filesep, '*.tdms');
            xlsx_files = strcat(folder, filesep, '*.xlsx');
            file_location = [dir(tdms_files); dir(xlsx_files)];
            
            if numel(file_location) > 1
                warning('Multiple TDMS/XLSX files found, choose your file: ')
                [tdms_fn, tdms_pn] = uigetfile(strcat(folder, filesep,...
                    '*.tdms;*.xlsx'));
                filename = strcat(tdms_pn, filesep, tdms_fn);
            else
                filename = strcat(file_location.folder, filesep, ...
                    file_location.name);
            end
            
            obj.FILENAME = filename;
            
        end
        
        function readFile(obj)
            
            [~, ~, data_format] = fileparts(obj.FILENAME);
            switch data_format
                
                case '.xlsx'
                    obj.readXLSX();
                    
                case '.tdms'
                    obj.readTDMS();
                    
            end

        end
        
        function readTDMS(obj)
            
            if ~exist('TDMS_readTDMSFile', 'file')
               error(strcat('Error. TDMS_readTDMSFile() not found.', ...
                   ' Please add it to the path. You can get it at ', ...
                   'https://www.mathworks.com/matlabcentral/',...
                   'fileexchange/30023-tdms-reader'))
            end
            
            behavior_file = TDMS_readTDMSFile(obj.FILENAME);
            
            behavior_data = behavior_file.data;
            obj.behavior_raw = struct;
            
            switch obj.VERSION
                
                case 'new'
                    
                    obj.behavior_raw.R = behavior_data{8}';
                    obj.behavior_raw.phi = behavior_data{9}';
                    obj.behavior_raw.alpha = behavior_data{10}';
                    
                    obj.behavior_raw.X = behavior_data{11}';
                    obj.behavior_raw.Y = -behavior_data{12}';
                    
                    if max(abs(obj.behavior_raw.X)) < 100 ...                   % In some neutorar versions, X and Y are normalized to 100,
                            && max(abs(obj.behavior_raw.Y)) < 100
                        obj.behavior_raw.X = 1.25 * obj.behavior_raw.X;
                        obj.behavior_raw.Y = 1.25 * obj.behavior_raw.Y;
                    end
                    
                    obj.behavior_raw.theta = behavior_data{13}';
                    obj.behavior_raw.beta = behavior_data{14}';
                    
                case 'old'
                    obj.behavior_raw.R = behavior_data{10}';
                    obj.behavior_raw.phi = behavior_data{11}';
                    obj.behavior_raw.alpha = behavior_data{12}';
                    obj.behavior_raw.X = behavior_data{13}';
                    obj.behavior_raw.Y = -behavior_data{14}';
                    
            end
            
            obj.behavior_raw.time = behavior_data{5};
            obj.behavior_raw.time = obj.behavior_raw.time - ...
                obj.behavior_raw.time(1);
            obj.behavior_raw.w = behavior_data{15}';
            obj.behavior_raw.speed = behavior_data{16}';
            obj.behavior_raw.zones = behavior_data{17}';
            
        end
        
        function readXLSX(obj)
            
            disp('reading XLSX')
            [~, ~, excel_data] = xlsread(obj.FILENAME, 3);
            
            behavior_raw = struct;
 
        end
        
    end
    
    % Postprocessing methods
    methods (Access = public)
        
        function reSample(obj)
            
            % This function takes the Neurotar sampling rate (typically 20ms or
            % 13ms) and resamples it taking into account the sampling rate of
            % the microscope and the exposition time. It does so by taking the
            % average when the window is open.
            
            obj.behavior = struct;
            
            microscope_rate = obj.SAMPLING_PERIOD;
            off_time = obj.OFF_TIME;
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
        
        function detectMovement(obj)
            
            % This function detects when the mouse is running and when is not
            % by detecting the moving bouts.
            %
            % Adapted from Will
            
            speed = obj.behavior.speed;
            speed = smooth(speed, 200, 'moving')';
            
            speed(speed>200) = 200;
            speed_thresh = 5;
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
        
%         function save(obj)
%             
%             save('C:\My folder\filename','varname')
%             
%             
%         end
        
    end
    
    
end



