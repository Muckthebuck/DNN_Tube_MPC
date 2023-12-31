function hFigure = helperPlotLFDetectionResults(...
    logsout, cameraSensorVideoFileName, scenario, cameraParam, radarParam, scenarioFcnName,...
    varargin)
% helperPlotLFDetectionResults Visualize lane following detections and record to movie
%
% Visualizes simulation results in a manner similar to the example:
%   Forward Collision Warning Using Sensor Fusion
%   web(fullfile(docroot, 'driving/examples/forward-collision-warning-using-sensor-fusion.html'))
%
% Required inputs
%   logsout:
%       Simulation log from HighwayLaneFollowingTestBench model
%   cameraSensorVideoFileName:
%       Video file of camera sensor logged from HighwayLaneFollowingTestBench model
%   scenario, cameraParam, radarParam, scenarioFcnName:
%       Variables generated by helperSLHighwayLaneFollowingSetup
%
% Optional inputs name/value pairs [default value]
%   RecordVideo:
%       Flag to record video [false]
%   RecordVideoFilename:
%       Name of generated video file ['DetectionResults']
%   DisplayTracks:
%       flag to plot tracks in birds eye plot [true]
%   DisplayBEPLegend:
%       Flag to display legend in birds eye plot [true]
%   OpenRecordedVideoInVideoViewer:
%       Flag to open generated video with Video Viewer app (implay) [false]
%   ForwardFacingCameraVideoFileName:
%       Logged video of camera sensor from simulation ['forwardFacingCamera.mp4'];
%
%   This is a helper script for example purposes and may be removed or
%   modified in the future.

%   Copyright 2019 The MathWorks, Inc.

    defaultRecordVideo = false;
    defaultRecordVideoFilename = 'DetectionResults';
    defaultDisplayTracks = true;
    defaultDisplayBEPLegend = true;
    defaultOpenRecordedVideoInVideoViewer = false;
    defaultVideoViewerJumpToTime = 0;
    
    p = inputParser;
    addParameter(p,'RecordVideo',defaultRecordVideo,@islogical);
    addParameter(p,'RecordVideoFilename',defaultRecordVideoFilename,@isstring);
    addParameter(p,'DisplayTracks',defaultDisplayTracks,@islogical);
    addParameter(p,'DisplayBEPLegend',defaultDisplayBEPLegend,@islogical);
    addParameter(p,'OpenRecordedVideoInVideoViewer',defaultOpenRecordedVideoInVideoViewer,@islogical);
    addParameter(p,'VideoViewerJumpToTime',defaultVideoViewerJumpToTime,@isnumeric);
    parse(p,varargin{:});
    
    recordVideo         = p.Results.RecordVideo;
    recordVideoFilename = p.Results.RecordVideoFilename;
    displayTracks       = p.Results.DisplayTracks;
    displayBEPLegend    = p.Results.DisplayBEPLegend;
    openRecordedVideoInVideoViewer   = p.Results.OpenRecordedVideoInVideoViewer;
    VideoViewerJumpToTime            = p.Results.VideoViewerJumpToTime;
    
    % Get logged signals
    hActors           = logsout.get('actors').Values;
    hVisionDetections = logsout.get('vehicle_detections').Values;
    hRadarDetections  = logsout.get('radar_detections').Values;
    hTracks           = logsout.get('tracks').Values;
    hMIOIndex         = logsout.get('mio').Values;
    hLaneDetections   = logsout.get('lane_detections').Values;

    % Create video writer
    if recordVideo
        pVideoWriter = VideoWriter(recordVideoFilename);
        pVideoWriter.FrameRate = 1 / scenario.SampleTime;
        open(pVideoWriter);
    end

    % Get vehicle profiles
    vehicleProfiles = actorProfiles(scenario);

    % Create figure
    [hFigure, videoReader, videoDisplayHandle, bepPlotters, sensor] = ...
        createFigure(cameraSensorVideoFileName, cameraParam, radarParam, vehicleProfiles(1),...
            scenarioFcnName, displayBEPLegend);

    numSamples = videoReader.NumFrames;
    
    for sampleIndex = 1:numSamples

        % Camera image
        frame = readFrame(videoReader);
        
        % Lane detections
        laneStrength = hLaneDetections.Left.Strength.Data(sampleIndex);
        laneCurvature = hLaneDetections.Left.Curvature.Data(sampleIndex);
        laneHeadingAngle = hLaneDetections.Left.HeadingAngle.Data(sampleIndex);
        laneLateralOffset = hLaneDetections.Left.LateralOffset.Data(sampleIndex);
        laneXExtent = hLaneDetections.Left.XExtent.Data(1,:,sampleIndex);
        laneBoundaryType = hLaneDetections.Left.BoundaryType.Data(sampleIndex);
        
        if laneStrength > 0
            laneBoundaries.Left = parabolicLaneBoundary([...
                laneCurvature/2,...
                laneHeadingAngle,...
                laneLateralOffset]);
            laneBoundaries.Left.Strength = laneStrength;
            laneBoundaries.Left.XExtent = laneXExtent;
            laneBoundaries.Left.BoundaryType = laneBoundaryType;
        else
            laneBoundaries.Left = parabolicLaneBoundary.empty;
        end
        
        laneStrength = hLaneDetections.Right.Strength.Data(sampleIndex);
        laneCurvature = hLaneDetections.Right.Curvature.Data(sampleIndex);
        laneHeadingAngle = hLaneDetections.Right.HeadingAngle.Data(sampleIndex);
        laneLateralOffset = hLaneDetections.Right.LateralOffset.Data(sampleIndex);
        laneXExtent = hLaneDetections.Right.XExtent.Data(1,:,sampleIndex);
        laneBoundaryType = hLaneDetections.Right.BoundaryType.Data(sampleIndex);
        
        if laneStrength > 0
            laneBoundaries.Right = parabolicLaneBoundary([...
                laneCurvature/2,...
                laneHeadingAngle,...
                laneLateralOffset]);
            laneBoundaries.Right.Strength = laneStrength;
            laneBoundaries.Right.XExtent = laneXExtent;
            laneBoundaries.Right.BoundaryType = laneBoundaryType;
        else
            laneBoundaries.Right = parabolicLaneBoundary.empty;
        end
           
        % Confirmed tracks
        if displayTracks
            numTracks = hTracks.NumTracks.Data(sampleIndex);
        else
            numTracks = 0;
        end
        tracks = repmat(struct(...
            'TrackID',0, 'State',zeros(6,1),'StateCovariance',zeros(6,6),'IsConfirmed', false),...
            numTracks,1);
        for k = 1:numTracks
            tracks(k).TrackID = hTracks.Tracks(k).TrackID.Data(:,1,sampleIndex);
            tracks(k).State = hTracks.Tracks(k).State.Data(:,1,sampleIndex);
            tracks(k).StateCovariance = hTracks.Tracks(k).StateCovariance.Data(:,:,sampleIndex);
            tracks(k).IsConfirmed = hTracks.Tracks(k).IsConfirmed.Data(:,1,sampleIndex);
            tracks(k).ObjectClassID = hTracks.Tracks(k).ObjectClassID.Data(:,1,sampleIndex);
            tracks(k).ObjectAttributes = [];
        end
        
        % Most important object
        if displayTracks
            mostImportantObject.TrackIndex = hMIOIndex.Data(sampleIndex);
        else
            mostImportantObject.TrackIndex = 0;
        end
        mostImportantObject.ThreatColor = 'Yellow';
        
        % Position and velocity selectors
        positionSelector = [1,0,0,0,0,0; 0,0,1,0,0,0]; % Position selector
        velocitySelector = [0,1,0,0,0,0; 0,0,0,1,0,0]; % Velocity selector

        % Vision object detections
        numDets = hVisionDetections.NumDetections.Data(sampleIndex);
        visObjPos = zeros(numDets,2);
        for k = 1:numDets
            visObjPos(k,:) = hVisionDetections.Detections(k).Measurement.Data(1:2,1,sampleIndex);
        end
        
        % Radar object detections
        numDets = hRadarDetections.NumDetections.Data(sampleIndex);
        radObjPos = zeros(numDets,2);
        for k = 1:numDets
            radObjPos(k,:) = hRadarDetections.Detections(k).Measurement.Data(1:2,1,sampleIndex);
        end

        % Actors
        numActors = hActors.NumActors.Data(sampleIndex);

        actors.Positions     = zeros(numActors,2);
        actors.Yaws          = zeros(numActors,1);
        actors.Lengths       = zeros(numActors,1);
        actors.Widths        = zeros(numActors,1);
        actors.OriginOffsets = zeros(numActors,2);
        actors.Colors   = ones(numActors,1) * [1 0 0]; % [1 0 0] = Red

        for n = 1:numActors
            m = hActors.Actors(n).ActorID.Data(sampleIndex);
            actors.Positions(n,:)     = hActors.Actors(n).Position.Data(1,(1:2),sampleIndex);
            actors.Yaws(n,:)          = hActors.Actors(n).Yaw.Data(sampleIndex);
            actors.Lengths(n,:)       = vehicleProfiles(m).Length;
            actors.Widths(n,:)        = vehicleProfiles(m).Width;
            actors.OriginOffsets(n,:) = vehicleProfiles(m).OriginOffset(1:2);
        end

        % Simulation time
        simulationTime = (sampleIndex - 1) * scenario.SampleTime;
        
        % Update display
        updateDisplay(frame, videoDisplayHandle, bepPlotters, ...
            laneBoundaries, sensor, tracks, mostImportantObject, positionSelector, velocitySelector, ...
            visObjPos, radObjPos, actors, simulationTime)

       % Write frame
        if recordVideo && ~isempty(pVideoWriter)
            writeVideo(pVideoWriter, getframe(hFigure));
        end
        
    end            
    
    % Write movie from recorded frames.
    if recordVideo && ~isempty(pVideoWriter)
        close(pVideoWriter);
        
        % If requested, open in movie player and close original figure
        if openRecordedVideoInVideoViewer
            % Open recorded movie
            hVideoViewer = implay(recordVideoFilename + ".avi");
            hVideoViewer.Parent.Position = hFigure.Position;
            
            % Jump to requested time
            VideoViewerDisplayFrame = 1 + round(VideoViewerJumpToTime / scenario.SampleTime);
            hVideoViewerControls = hVideoViewer.DataSource.Controls;
            jumpTo(hVideoViewerControls,VideoViewerDisplayFrame)
            
            % Close original figure when movie is requested
            close(hFigure);
            
            % Return handle to movie player
            hFigure = hVideoViewer;
        end
    end
end

%% Create Figure for Visualization
function [hFigure, videoReader, videoDisplayHandle, bepPlotters, sensor] = ...
    createFigure(videoFileName, cameraParam, radarParam, egoProfile, scenarioFcnName, displayBEPLegend)
% Creates the display figure 

% Define container figure
figureName = 'Lane Following Plot';

scrsz = double(get(groot,'ScreenSize'));
figurePosition = [10 10 scrsz(3)*.8 scrsz(4)*0.8];
hFigure = figure('Name',figureName,'Position',figurePosition);
hFigure.NumberTitle = 'off';

% Bring figure to front
figure(hFigure);

% Read video frame
videoReader = VideoReader(videoFileName);
frame = readFrame(videoReader);

% Define the video objects
hVideoAxes = axes(hFigure, 'Units', 'Normal', 'Position', [0.01 0.01 0.49 0.88]);
videoDisplayHandle = createVideoDisplay(frame, hVideoAxes, scenarioFcnName);

% Define the birdsEyePlot and plotters
bepAxes = axes(hFigure, 'Units', 'Normal', 'Position', [0.55 0.1 0.44 0.78]);
bepPlotters = createBirdsEyePlot(bepAxes, cameraParam, radarParam, egoProfile, displayBEPLegend);

% Monocamera sensor
camIntrinsics = cameraIntrinsics(cameraParam.FocalLength, cameraParam.PrincipalPoint, cameraParam.ImageSize);
sensor = monoCamera(camIntrinsics, cameraParam.Position(3), 'Pitch', cameraParam.Rotation(2));
    
% Reset the video reader to the first frame
videoReader.CurrentTime = 0;
end

function videoFrame = createVideoDisplay(frame, hVideoAxes, scenarioFcnName)
% Initialize Video I/O
% Create objects for reading a video from a file and playing the video.
%
% Create a video player and display the first frame
videoFrame = imshow(frame, [], 'Parent', hVideoAxes);
hVideoAxes.Title.String = scenarioFcnName + newline + "Front Facing Camera";
hVideoAxes.Title.Interpreter = 'none';
end

function bepPlotters = createBirdsEyePlot(bepAxes, cameraParam, radarParam, egoProfile, displayBEPLegend)
% Creates a birdsEyePlot object and returns a struct of birdsEyePlotter
% objects. The birdsEyePlot is shown on the right half of the display.
%
% A birdsEyePlot is a plot that is configured to use the ego-centric car
% coordinate system, where the x-axis is pointed upwards, in front of the
% car, and the y-axis is pointed to the left. 
%
% To create a birdsyEyePlot the following steps are performed:
% 
% # Read sensor positions and coverage areas from |sensorConfigurationFile|
% # Create a birdsEyePlot in the defined axes. If none are defined, they will be created.
% # Create coverage area plotters for the vision and radar sensors.
% # Use the coverage area plotters to plot the sensor coverages.
% # Create detection plotters for each sensor.
% # Create track plotter for all the tracks.
% # Create track plotter for the most important object (MIO).
% # Create lane boundary plotter.

% If no axes are specified, they will be created by bird's-eye plot
if nargin == 1
    bepAxes = [];
end

%Create the birds-eye plot object
BEP = birdsEyePlot('Parent',bepAxes,'XLimits',[0 90],'YLimits',[-35 35]);
if ~displayBEPLegend
    legend off
end

% Add title
bepPlotters.Title = BEP.Parent.Title;
bepPlotters.Title.String = 'Birds-Eye Plot';

%Create outline plotter for ego actor
% - first actor in scenario is considered ego
bepPlotters.EgoOutline = outlinePlotter(BEP);
colorBlue  = [0 0.447 0.741];
plotOutline(bepPlotters.EgoOutline,...
    [0,0], 0, egoProfile.Length, egoProfile.Width,...
    'OriginOffset',egoProfile.OriginOffset(1:2),...
    'Color',colorBlue);

% create outline plotter for target actors
bepPlotters.TargetOutline = outlinePlotter(BEP);

% create the sensor coverage areas
capCamera  = coverageAreaPlotter(BEP,'FaceColor','blue','EdgeColor','blue');
capRadar = coverageAreaPlotter(BEP,'FaceColor','red','EdgeColor','red');

% plot the sensor coverage areas
plotCoverageArea(capRadar, [radarParam.Position(1), radarParam.Position(2)],...
    radarParam.DetectionRanges(2), radarParam.Rotation(3), radarParam.FieldOfView(1));
plotCoverageArea(capCamera, [cameraParam.Position(1), cameraParam.Position(2)],...
    cameraParam.DetectionRanges(2), cameraParam.Rotation(3), cameraParam.FieldOfView(1));

% create a vision detection plotter put it in a struct for future use
bepPlotters.Vision = detectionPlotter(BEP, 'DisplayName','vision detection', ...
    'MarkerEdgeColor','blue', 'Marker','^');

% we'll combine all radar detctions into one entry and store it
% for later update
bepPlotters.Radar = detectionPlotter(BEP, 'DisplayName','radar detection', ...
    'MarkerEdgeColor','red');

% Show last 10 track updates
bepPlotters.Track = trackPlotter(BEP, 'DisplayName','tracked object', ...
    'HistoryDepth',10);

% Allow for a most important object
bepPlotters.MIO = trackPlotter(BEP, 'DisplayName','most important object', ...
    'MarkerFaceColor','yellow');

% Left lane boundary
bepPlotters.LeftLaneBoundary = laneBoundaryPlotter(BEP, ...
    'DisplayName','left lane boundary', 'Color','red');

% Right lane boundary
bepPlotters.RightLaneBoundary = laneBoundaryPlotter(BEP, ...
    'DisplayName','right lane boundary', 'Color','green');

% Lock the legend for speedup
set(BEP.Parent.Legend, 'AutoUpdate', 'off'); 

end

%% Update Display
function updateDisplay(frame, videoDisplayHandle, bepPlotters, ...
    laneBoundaries, sensor, confirmedTracks, mostImportantObject, positionSelector, velocitySelector, ...
    visObjPos, radObjPos, actors, simulationTime)
% This helper function updates the display for the forward collision
% warning example.
updateVideoDisplay(videoDisplayHandle, frame, laneBoundaries, sensor, confirmedTracks, positionSelector, mostImportantObject);
updateBirdsEyePlot(bepPlotters, laneBoundaries, visObjPos, radObjPos, confirmedTracks, positionSelector, velocitySelector, mostImportantObject, actors, simulationTime);

end
%--------------------------------------------------------------------------

function updateVideoDisplay(videoDisplayHandle, frame, laneBoundaries, sensor, confirmedTracks, positionSelector, MIO)
% updates the video display with a new annotated frame

% Call the helper function to annotate the frame
annotatedFrame = annotateVideoFrame(frame, laneBoundaries, sensor, confirmedTracks, positionSelector, MIO);

% Display the annotated frame
if isvalid(videoDisplayHandle)
    set(videoDisplayHandle, 'CData', annotatedFrame);
end
end

function annotatedFrame = annotateVideoFrame(frame, laneBoundaries, sensor, confirmedTracks, positionSelector, MIO)
% annotates a video frame 

if ~isempty(laneBoundaries.Left)
    % XY points for left lane marker
    xRangeVehicle = laneBoundaries.Left.XExtent;
    xPtsInVehicle = linspace(xRangeVehicle(1), xRangeVehicle(2), 100)';

    % Display the left lane boundary on the video frame
    frame = insertLaneBoundary(frame, laneBoundaries.Left, sensor, xPtsInVehicle,'Color','red');
end

if ~isempty(laneBoundaries.Right)
    % XY points for right lane marker
    xRangeVehicle = laneBoundaries.Right.XExtent;
    xPtsInVehicle = linspace(xRangeVehicle(1), xRangeVehicle(2), 100)';

    % Display the right lane boundary on the video frame
    frame = insertLaneBoundary(frame, laneBoundaries.Right, sensor, xPtsInVehicle,'Color','green');
end

% Display tracks as bounding boxes on video frame
xRangeVehicle = [1 100];
annotatedFrame = insertTrackBoxes(frame, sensor, confirmedTracks, xRangeVehicle, ...
    MIO.ThreatColor, MIO.TrackIndex, positionSelector);
end
%--------------------------------------------------------------------------

function I = insertTrackBoxes(I, sensor, tracks, xVehicle, threatColor, mioTrackIndex, positionSelector)
% insertTrackBoxes  Inserts bounding boxes in an image based on the
% distance in front of the ego vehicle, as measured by the track's position
% in front of the car
% Note: the function assumes that the first element in the position vector
% is the relative distance in front of the car

    % Define the classification values used in the tracking
    ClassificationValues = {'Unknown', 'Car'};
    
    if isempty(tracks)
        return
    end

    % Extract the state vector from all the tracks    
    positions = getTrackPositions(tracks, positionSelector); % Gets a matrix of all the positions
    xs = positions(:,1);

    % Only use tracks that are confirmed and within the defined xVehicle range
    set1 = (xVehicle(1) <= xs);
    set2 = (xs <= xVehicle(2));    
    set = set1 .* set2;
    tracks = tracks(set == 1);
    xs = xs(set == 1);

    % Make sure the resulting set is not empty
    if isempty(tracks)
        return
    end

    % Sort in descending order by distance forward. This way, the last added
    % annotation will be the nearest.
    [~, sortindx] = sortrows(xs, -1);
    classes = [tracks(:).ObjectClassID]';

    % Memory allocation
    labels = cell(numel(tracks),1);
    bboxes = zeros(numel(tracks), 4);
    colors = cellstr(repmat('white', numel(tracks),1));

    for i = 1:numel(tracks)
        k = sortindx(i);
        
        % Convert to image coordinates using monoCamera object
        xy = (positionSelector * tracks(k).State)';      
        
        if classes(k)>0 % object classification available?
            % size will be in ObjectAttributes, which can be cell or struct
            if iscell(tracks(k).ObjectAttributes)
                size = cell2mat(tracks(k).ObjectAttributes{1,1}(2)); % read object size
            elseif isstruct(tracks(k).ObjectAttributes) && isfield(tracks(k).ObjectAttributes, 'Size')
                size = tracks(k).ObjectAttributes.Size;
            else 
                size = [0,1.8,0]; % set default width = 1.8m
            end
            width = size(2);
        else
            width = 1.8; % set default width = 1.8m
        end
        
        xyLocation1 = vehicleToImage(sensor, [xy(1), xy(2)] + [0,width/2]);
        xyLocation2 = vehicleToImage(sensor, [xy(1), xy(2)] - [0,width/2]);
        W = xyLocation2(1) - xyLocation1(1);
        
        % Define the height/width ratio based on object class
        switch classes(k)
            case {3,4} % Pedestrian or Bike                   
                H = W * 3;
            case {5,6} % Car or Truck
                H = W * 0.85;
            otherwise
                H = W;
        end
        
        % Estimate the bounding box around the vehicle. Subtracting the height
        % of the bounding box to define the top-left corner.
        bboxes(i,:) =[(xyLocation1 - [0, H]), W, H];

        % Add label: track ID + class
        labels{i} = [num2str(tracks(k).TrackID), '  ', ClassificationValues{classes(k) + 1}];        

        % The MIO gets the color based on FCW
        if k == mioTrackIndex
            colors{i} = threatColor;
        end
    end
    I = insertObjectAnnotation(I, 'rectangle', bboxes, labels, 'Color', colors, ...
        'FontSize', 10, 'TextBoxOpacity', .8, 'LineWidth', 2);
end

function updateBirdsEyePlot(bepPlotters, laneBoundaries, visObjPos, ...
    radObjPos, confirmedTracks, positionSelector, velocitySelector, ...
    mostImportantTrack, actors, simulationTime)
%  Updates the bird's-eye plot with information about lane boundaries,
%  vision and radar detections, confirmed tracks and most important object.

% Update title
bepPlotters.Title.String = "Birds-Eye Plot (" + num2str(simulationTime,'%4.1f') + " sec)";

% Prepare tracks and most important object:
trackIDs = {confirmedTracks.TrackID};
trackLabels = cellfun(@num2str, trackIDs, 'UniformOutput', false);
[trackPositions, trackCovariances] = getTrackPositions(confirmedTracks, positionSelector);
trackVelocities = getTrackVelocities(confirmedTracks, velocitySelector);

% Update all BEP objects
% Display the birdsEyePlot
plotLaneBoundary(bepPlotters.LeftLaneBoundary, laneBoundaries.Left)
plotLaneBoundary(bepPlotters.RightLaneBoundary, laneBoundaries.Right)
plotDetection(bepPlotters.Radar, radObjPos);
plotDetection(bepPlotters.Vision, visObjPos);
plotTrack(bepPlotters.Track, trackPositions, trackVelocities, trackCovariances, trackLabels);
plotOutline(bepPlotters.TargetOutline,...
    actors.Positions, actors.Yaws, actors.Lengths, actors.Widths,...
    'OriginOffset',actors.OriginOffsets,...
    'Color', actors.Colors);        
if mostImportantTrack.TrackIndex > 0
    bepPlotters.MIO.MarkerFaceColor = mostImportantTrack.ThreatColor;
    plotTrack(bepPlotters.MIO, trackPositions(mostImportantTrack.TrackIndex,:), trackVelocities(mostImportantTrack.TrackIndex,:), trackLabels(mostImportantTrack.TrackIndex));
else
    clearData(bepPlotters.MIO);
end
end
