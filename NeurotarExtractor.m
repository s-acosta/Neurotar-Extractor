classdef NeurotarExtractor < handle
    
    % Properties we are interested as output
    properties (Access = public)
        behavior            struct
        behavior_raw        struct
    end
    
    properties (Access = private)
        options
        session_id
    end
    
    % Initializing methods
    methods (Access = public)
        
        function obj = NeurotarExtractor(session_id, varargin)
            
            obj.options = inputParser;
            addParameter(obj.options, 'ImagingMethod','WideField')
            addParameter(obj.options, 'SamplingWindow', 100)
            addParameter(obj.options, 'OffTime', 25)
            addParameter(obj.options, 'Version', 'New')
            parse(obj.options,varargin{:})
            
            if nargin == 0
                obj.getSession()
            else
                obj.session_id = session_id;
            end
            
            obj.checkIDName()
            obj.readTDMS()
            
            obj.resampling()
            obj.movingDetector()
            
        end
        
    end
     
    % Convert from .tdms methods. TDMS functions need to be in path
    methods (Access = private)
         
        function checkIDName(obj)
            
            mouse_date = strsplit(obj.session_id, '_');
            success = 0;
            
            while success == 0
                try
                    assert(isequal(isstrprop(mouse_date{1},'alpha'),[1 1 1 0 0 0]),...
                        'Session ID incorrect (mouse should be LLLNNN)');
                    assert(isequal(isstrprop(mouse_date{2},'digit'),[1 1 1 1 1 1]), ...
                        'Session ID incorrect,(date should be YYMMDD)');
                    success = 1;
                   
                catch ME
                    msg = errordlg(ME.message,'ID Error');
                    pause(2)
                    getSession(obj)
                    close(msg)
                    return
                end
            end
            
        end
        
        function getSession(obj)
            
            prompt = {'Enter session ID [mouse_date(Y/M/D)]:'};
            dlgtitle = 'Input';
            dims = [1 35];
            definput = {'SAM000_201205'};
            obj.session_id = char(inputdlg(prompt,dlgtitle,dims,definput));
            
        end
        
        function readTDMS(obj)
            
            file = strcat(obj.session_id,'.tdms');
            
            try
                
            behavior_file = TDMS_readTDMSFile(file);
            
            catch ME
                msg_1 = errordlg(ME.message,'ID Error');
                pause(2)
                
                getSession(obj)
                close(msg_1)
               
                readTDMS(obj)
                
            end
           
            behavior_data = behavior_file.data;
            obj.behavior_raw = struct;
            
            switch obj.options.Results.Version
                
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
                    
                    obj.options.Results.Version = answer;
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
            
            microscope_rate = obj.options.Results.SamplingWindow;
            off_time = obj.options.Results.OffTime;
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
        
        

