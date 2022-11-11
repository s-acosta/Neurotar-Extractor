%% Neurotar Extractor Master
% Default Parameters:
%   CAGE_RADIUS = 125
%   ANGLE_TYPE = 'Positive'
%   RECORDING_RATE = 10
%   SPEED_THRESHOLD = 10;
%   BOUT_THRESHOLD = 10;
%   isMoving = false
%   isRecording = true

%% - To get raw data 
Neurotar = NewNeurotarExtractor('SAM003_220729', isRecording = false, ...
    isMoving = false);

X = Neurotar.X;
Y = Neurotar.Y;
alpha = Neurotar.alpha;
R = Neurotar.R;
speed = Neurotar.speed;

%% Resampled to recording
% If we want to align with recording, in this case a 30 min recording (18000
% frames when prompted). Notice how variables are now of length 18000

Neurotar = NewNeurotarExtractor('SAM003_220729', isMoving = false, ...
    RECORDING_FRAMES = 18000);

X = Neurotar.X;
Y = Neurotar.Y;
alpha = Neurotar.alpha;
R = Neurotar.R;
speed = Neurotar.speed;

%% Only moving times
% To get only the variables when the mouse is moving (with bouts of at
% least 10 with speed higher than 10, these values can be changed)

Neurotar = NewNeurotarExtractor('SAM003_220729', isMoving = true);

X = Neurotar.X;
Y = Neurotar.Y;
alpha = Neurotar.alpha;
R = Neurotar.R;
speed = Neurotar.speed;

% See how variables are now way shorter than 18k frames, to align our spike
% data we can use:

moving_times = Neurotar.moving_times;

% this is a logical vector of length 18k with the times the mouse is
% considered to be moving, if we had a spike vector like:

spikes = ones(1, 18000);

% we would remove the non-moving times by:
spikes_moving = spikes(moving_times);




