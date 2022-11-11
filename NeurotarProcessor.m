classdef NeurotarProcessor < handle

    properties (Access = public)

        FILENAME
        CAGE_RADIUS = 125
        CAGE_TYPE = 'Pentagon'
        ANGLE_TYPE = 'Positive'
        RECORDING_FRAMES = 12000
        RECORDING_RATE = 10
        data
        egocentric_params
        allocentric_params
 
    end

    properties
        QP
        pose
        isRecording = 1
    end

    methods

        function obj = NeurotarProcessor(session, options)

            arguments
                session
                options.Empty = false;
            end

            obj.setEgocentricParams();
            obj.setAllocentricParams();

            if ~options.Empty
            
                if nargin == 0
                    obj.getFilename();
                else
                    obj.FILENAME = strcat(session, '.tdms');
                end

            end

            prompt = "How many recording frames ? ";
            obj.RECORDING_FRAMES = input(prompt);

        end

    end

    % Reading methods
    methods

        function getFilename(obj)

            folder = uigetdir([], 'Choose the folder containing the file:');

            tdms_files = strcat(folder, filesep, '*.tdms');
            file_location = dir(tdms_files);
            filename = strcat(file_location.folder, filesep, ...
                file_location.name);
            obj.FILENAME = filename;

        end

        function data = readTDMS(obj)

            data = tdmsread(obj.FILENAME);
            obj.data = data{1,3};
            obj.addPose(isMoving = true);

        end

    end
    
    methods

        function setEgocentricParams(obj, options)

            arguments
                obj
                options.nBinsDist = 10;
                options.nBinsTheta = 30;
                options.LimDistance = [0 125];
                options.LimTheta = [0 2*pi];
            end

            obj.egocentric_params = options;
            lim_dist = obj.egocentric_params.LimDistance;
            lim_theta = obj.egocentric_params.LimTheta;
            n_bins_dist = obj.egocentric_params.nBinsDist;
            n_bins_theta = obj.egocentric_params.nBinsTheta;
            
            bins_dist = linspace(lim_dist(1), lim_dist(2), n_bins_dist);
            bins_theta = linspace(lim_theta(1), lim_theta(2), n_bins_theta);

            obj.egocentric_params.bins_dist = bins_dist;
            obj.egocentric_params.bins_theta = bins_theta;

        end

        function setAllocentricParams(obj, options)

            arguments
                obj
                options.nBins = 15;
                options.Lim = [-125 125];
            end

            obj.allocentric_params = options;
            
            [bins_x, bins_y] = deal(linspace(options.Lim(1), ...
                options.Lim(2), options.nBins));
            
            obj.allocentric_params.bins_x = bins_x;
            obj.allocentric_params.bins_y = bins_y;

        end

        function [plot_x, plot_y] = getEgocentricPlotVectors(obj)

            bins_dist = obj.egocentric_params.bins_dist;
            bins_theta = obj.egocentric_params.bins_theta;

            [t, r] = meshgrid(wrapTo2Pi(bins_theta + pi/2), bins_dist);
            [plot_x, plot_y] = pol2cart(t, r);

        end

        function [plot_x, plot_y] = getAllocentricPlotVectors(obj)

           plot_x = obj.allocentric_params.bins_x;
           plot_y = obj.allocentric_params.bins_y;

        end

    end


    % Extracting and microscope-matching methods
    methods

        function raw_variable = extractField(obj, variable_name)

            raw_variable = obj.data.(variable_name);

        end

        function behavior_variable = getField(obj, variable_name)

            raw_variable = obj.extractField(variable_name);

            switch variable_name

                case 'X'

                    behavior_variable = obj.CAGE_RADIUS/100 * raw_variable;

                case 'Y'

                    behavior_variable = - obj.CAGE_RADIUS/100 * raw_variable;

                case 'alpha'

                    switch obj.ANGLE_TYPE

                        case 'Positive'

                            behavior_variable = wrapTo360(90 - raw_variable);

                    end

                otherwise

                    behavior_variable = raw_variable;

            end

        end

        function behavior_variable = getRecordingField(obj, variable_name)

            variable = obj.getField(variable_name);
            cropped_variable = obj.cropToRecording(variable);
            behavior_variable = obj.downSample(cropped_variable);

        end

        function cropped_variable = cropToRecording(obj, variable)

            microscope_time = getField(obj, 'HW_timestamp') < ...
                (obj.RECORDING_FRAMES * (1/obj.RECORDING_RATE) * 1000);
            cropped_variable = variable(microscope_time);

        end

        function down_sampled = downSample(obj, variable)

            original_frames = 1:length(variable);
            desired_frames = linspace(1, length(variable), obj.RECORDING_FRAMES);
            down_sampled = interp1(original_frames, variable, desired_frames);

        end

    end

    % Get behavior variables
    methods

        function pose = getPose(obj)

            if obj.isRecording
                X = getRecordingField(obj, 'X');
                Y = getRecordingField(obj, 'Y');
                alpha = getRecordingField(obj, 'alpha');

            else
                X = getField(obj, 'X');
                Y = getField(obj, 'Y');
                alpha = getField(obj, 'alpha');
            end

            pose = [X; Y; alpha];

        end

        function [] = addPose(obj, options)

            arguments
                obj
                options.isMoving = false;
            end

            pose_temp = obj.getPose();

            if options.isMoving
                is_moving = obj.detectMovement();
                pose_temp = pose_temp(:, is_moving);
            end

            obj.pose = pose_temp;

        end

        function speed = getSpeed(obj)

            if obj.isRecording
                speed = getRecordingField(obj, 'Speed');
            else
                speed = getField(obj, 'Speed');
            end

        end

        function QP = getArena(obj)

            x = obj.pose(1, :);
            y = obj.pose(2, :);

            theta = 0:1:360;
            x_ntar = obj.CAGE_RADIUS * cosd(theta);
            y_ntar = obj.CAGE_RADIUS * sind(theta);

            h = figure('Position', [173,238,657,546]);
            set(h, 'Name', ...
                'Select Edge. Enter when done, Space to repeat, Esc to exit')
            ax = gca;
            axis equal

            plot(ax, x, y, 'Color', [.5 .5 .5], 'LineWidth', 0.2);
            hold on
            plot(ax, x_ntar, y_ntar, 'b', 'LineWidth', 2);
            h3 = [];
            h4 = [];

            isDone = false;

            while ~isDone

                delete(h3)
                delete(h4)

                [x_vtx, y_vtx, ~] = ginput(1);

                h3 = scatter(ax, x_vtx, y_vtx, 70, 'filled', 'r');
                hold on

                pause(.3)

                [~, min_idx] = min((x_vtx - x_ntar).^2 + (y_vtx - y_ntar).^2);

                QP = zeros(2, 5);

                for i = 0:4

                    vertix_idx = mod(min_idx + i * 72, length(theta));

                    QP(:, i+1) = [x_ntar(vertix_idx), y_ntar(vertix_idx)];

                end

                delete(h3)

                h3 = scatter(ax, QP(1, :), QP(2, :), 70, 'filled', 'r');

                pause(0.4)

                delete(h3)

                pgon = polyshape(QP(1, :), QP(2, :));

                h4 = plot(pgon, 'FaceColor','blue', 'FaceAlpha', 0.3);

                [in, ~] = inpolygon(obj.pose(1,:), obj.pose(2,:), ...
                    QP(1, :), QP(2, :));
                points_out = 100 * (length(in)-sum(in)) / length(in);

                fprintf(1, '%2.2f percent of points are outside arena', points_out);
                disp(' ')

                waitforbuttonpress;
                button = double(get(gcf,'CurrentCharacter'));

                switch button

                    case 27                     % ESC: Exit altogether
                        pause(1.2)
                        close(h)
                        return

                    case 13
                        isDone = true;          % INTRO: Done
                        pause(1.2)
                        close(h)

                    case 32                     % SPACE: Repeat
                        pause(1.2)
                        continue

                    otherwise
                        msg = msgbox('Key not recognized. Please use escp/ent/space next time');
                        pause(1.2)
                        close(msg)
                        continue

                end

            end

            obj.QP = QP;

        end

    end

    % Detect movement
    methods

        function is_moving= detectMovement(obj, options)

            arguments
                obj
                options.SpeedThreshold = 10;
                options.BoutThreshold = 10;
            end

            speed = obj.getSpeed();
            speed = smooth(speed, 10, 'moving')';

            speed(speed>200) = 200;
            speed_thresh = options.SpeedThreshold;
            bout_thresh = options.BoutThreshold;

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

            is_moving = moving_time(2:end-1);

        end

    
    end


    % Compute occupancies
    methods

        function occ_t = getAllocentricOccupancy(obj)

            n_bins = obj.allocentric_params.nBins;
            bins_x = obj.allocentric_params.bins_x;
            bins_y = obj.allocentric_params.bins_y;

            x_binned = discretize(obj.pose(1,:), bins_x);
            y_binned = discretize(obj.pose(2,:), bins_y);
            is_nan = isnan(x_binned + y_binned);
            xy_binned = sub2ind([n_bins n_bins], y_binned, x_binned);

            occ_t = false(n_bins * n_bins, size(obj.pose, 2));

            for t = 1:size(obj.pose, 2)

                if ~is_nan(t)
                    occ_t(xy_binned(t), t) = true;
                end

            end

            occ_t = reshape(occ_t, [n_bins n_bins size(obj.pose, 2)]);

        end

        function occ_t = getEgocentricOccupancy(obj)

            if isempty(obj.QP)
                obj.getArena()
            end

            lim_dist = obj.egocentric_params.LimDistance;
            lim_theta = obj.egocentric_params.LimTheta;
            n_bins_dist = obj.egocentric_params.nBinsDist;
            n_bins_theta = obj.egocentric_params.nBinsTheta;

            max_dist = 1000;

            x = obj.pose(1, :);
            y = obj.pose(2, :);
            head_dir = obj.pose(3, :);

            if max(head_dir) > 90
                head_dir = deg2rad(head_dir);
            end

            head_dir = wrapTo2Pi(head_dir);

            [in, ~] = inpolygon(x, y, obj.QP(1, :), obj.QP(2, :));
            x(~in) = nan;
            y(~in) = nan;

            bins_dist = linspace(lim_dist(1), lim_dist(2), n_bins_dist);
            bins_theta = linspace(lim_theta(1), lim_theta(2), n_bins_theta);

            n_time = length(x);
            pgon = polyshape(obj.QP(1, :), obj.QP(2, :));

            occ_t = false(n_bins_dist, n_bins_theta, n_time);

            for t = 1:n_time

                if isnan(x(t) + y(t)+ head_dir(t))
                    continue
                end

                for th = 1:n_bins_theta

                    line = [x(t) y(t); x(t) + max_dist * cos(head_dir(t) + bins_theta(th)) ...
                        y(t) + max_dist * sin(head_dir(t) + bins_theta(th))];

                    intersects = intersect(pgon, line);
                    intersects = intersects(2, :);

                    dp = intersects - [x(t) y(t)];
                    d_idx = discretize(norm(dp), bins_dist);

                    if ~isnan(d_idx)
                        occ_t(d_idx, th, t) = true;
                    end

                end

            end

        end

    end


    % Plot things
    methods

        function showTrajectory(obj)

            x = obj.pose(1, :);
            y = obj.pose(2, :);
            head_dir = obj.pose(3, :);

            fig = figure(1);
            for t = 1:size(obj.pose, 2)

                if ~ishghandle(fig)
                    break
                end
                clf(fig)

                xy_mouse = mouseCreator(x(t), y(t), head_dir(t));
                h1 = plot(xy_mouse(1,:), xy_mouse(2,:), 'Color', 'k');
                hold on
                pgon = polyshape(obj.QP(1, :), obj.QP(2, :));
                plot(pgon, 'FaceColor','blue', 'FaceAlpha', 0.3);
                hold off
                axis square
                xlim([-150 150])
                ylim([-150 150])

                drawnow()
                pause(0.05)
                delete(h1)

            end

        end

        function showHeadDir(obj)

            figure,
            is_moving = obj.detectMovement();
            pgon = polyshape(obj.QP(1, :), obj.QP(2, :));
            plot(pgon, 'FaceColor', 'red', 'FaceAlpha', 0.2, 'LineWidth', 2)
            hold on
            scatter(obj.pose(1,is_moving), obj.pose(2, is_moving), 25, ...
                obj.pose(3, is_moving), 'filled')
            colormap('hsv')
            caxis([0 360])
            colorbar
            axis square


        end

        function fig = showOccupancies(obj, allo_occ, ego_occ)

            is_moving = obj.detectMovement;

            if nargin < 2
                allo_occ = obj.getAllocentricOccupancy();
                allo_occ = sum(allo_occ, 3);
%                 allo_occ = sum(allo_occ(:, :, is_moving), 3);
                ego_occ = obj.getEgocentricOccupancy();
                ego_occ = sum(ego_occ, 3);
%                 ego_occ = sum(ego_occ(:, :, is_moving), 3);
            end

            ego_occ = obj.smoothEgoMat(ego_occ, [1 1], 1.5);
            allo_occ = imgaussfilt(allo_occ, 1.5, 'FilterSize', 3);

            [ego_x, ego_y] = obj.getEgocentricPlotVectors();
            [allo_x, allo_y] = obj.getAllocentricPlotVectors();

            fig = figure('units', 'normalized', 'position', [0.08,0.3,0.85,0.4], ...
                'color', [1 1 1]);
            t = tiledlayout(1,3);
            title(t, strrep(obj.FILENAME, '_', '-'), 'FontSize', 16)

            ax1 = nexttile;
            pgon = polyshape(obj.QP(1, :), obj.QP(2, :));
            plot(pgon, 'FaceColor', 'red', 'FaceAlpha', 0.2, 'LineWidth', 2)
            hold on
            scatter(obj.pose(1, :), obj.pose(2, :), 25, ...
                obj.pose(3,:), 'filled')
            colormap(ax1, 'hsv')
            caxis(ax1, [0 360])
            colorbar
            axis square

            ax2 = nexttile;
            pgon = polyshape({[-130 -130 130 130], obj.QP(1, :)}, ...
                {[130 -130 -130 130], obj.QP(2, :)});
            plot(ax2, pgon, 'FaceColor', 'w', 'FaceAlpha', 1, 'EdgeColor', 'w');
            h = surface(ax2, allo_x, allo_y, allo_occ);
            set(h,'ZData',-1+zeros(size(allo_occ)))
            shading interp
            axis square
            caxis(ax2, [0 prctile(allo_occ, 99, 'all') ])
            xlim(ax2, [-150 150])
            ylim(ax2, [-150 150])
            hold off
            colorbar

            ax3 = nexttile;
            surface(ax3, ego_x, ego_y, ego_occ)
            caxis(ax3, [0 prctile(ego_occ, 99, 'all')])
            colorbar
            axis square
            shading interp

        end

    end


    methods (Static)

        function [xy_mouse] = mouseCreator(x0,y0,h)

            b = 7.5;
            a = 10;

            xy_circle = circle(0,0,b,25);
            xy_elipse = elipse(-2*b,0,a,b,40);
            xy_line = line(-a-2*b,0,15);

            xy_mouse = [xy_circle xy_elipse xy_line];
            xy_mouse = rotation(xy_mouse,h) + [x0;y0];

            function [xy_obj] = rotation(xy_obj,h_obj)
                ROT_OBJ = [cosd(h_obj),-sind(h_obj);sind(h_obj),cosd(h_obj)];
                xy_obj = ROT_OBJ*xy_obj;
            end

            function [xy_circle] = circle(x0,y0,rad,n)
                angle = linspace(0,360,n);
                x_circle = rad * cosd(angle) + x0;
                y_circle = rad * sind(angle) + y0;
                xy_circle = [x_circle;y_circle];
            end

            function [xy_elipse] = elipse(x0,y0,a,b,n)
                angle = linspace(0,360,n);
                x_elipse = a*cosd(angle) + x0;
                y_elipse = b*sind(angle) + y0;
                xy_elipse = [x_elipse;y_elipse];
            end

            function xy_line = line(x0,y0,n)
                y_line = y0*ones(1,n);
                x_line = linspace(x0-30,x0,n);
                xy_line = [x_line;y_line];
            end

        end

        function smoothed_mat = smoothEgoMat(mat, kernel_size, std)

            % Smooths matrix by convolving with 2d gaussian of size
            % kernel_size=[bins_x bins_y] and standard deviation 'std'
            %
            % if std==0, just returns mat

            nd = size(mat, 2);
            mat = [mat mat mat];

            if nargin < 3
                std = 1;
            end

            if std == 0, return; end

            [Xgrid, Ygrid] = ...
                meshgrid(-kernel_size(1)/2: kernel_size(1)/2, ...
                -kernel_size(2)/2:kernel_size(2)/2);
            Rgrid = sqrt((Xgrid.^2 + Ygrid.^2));

            kernel = pdf('Normal', Rgrid, 0, std);
            kernel = kernel ./ sum(sum(kernel));
            mat = conv2(mat, kernel, 'same');
            smoothed_mat = mat(:, nd + 1 : 2 * nd);

        end
    
    
    end


end



