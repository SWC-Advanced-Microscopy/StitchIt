function out = determineStitchedImageExtent
    % Determine the size of the stitched images when stitching using tile positions
    %
    %
    % Purpose
    % When sitching using tile positions, individual sections may have slightly different sizes. 
    % With auto-ROI the sections will be very different sizes. In order to produces a series of
    % stitched images having the same size from section to section we need to determine the 
    % locations of all the tiles in the whole sample and find the extrema in the x/y plane. 
    % This functio does this. 
    %
    % Inputs - none. just run from sample directory
    %
    % Outputs - 
    % out - a structure with the extrema
    %
    %
    % Rob Campbell - SWC 2020


    out=[];
    [data,successfulRead]=readMetaData2Stitchit;

    if ~successfulRead
        fprintf('Failed to find acquisition in current directory\n')
        return
    end

    %Load the INI file and extract default values from it
    userConfig=readStitchItINI;

    if ~exist(userConfig.subdir.rawDataDir, 'dir')
        fprintf('Found no raw data directory\n')
        return
    end

    rDataDirs = dir(fullfile(userConfig.subdir.rawDataDir,[directoryBaseName,'*']));

    % Pre-allocate
    out.minXPos = nan(1,length(rDataDirs));
    out.minYPos = nan(1,length(rDataDirs));
    out.maxXPos = nan(1,length(rDataDirs));
    out.maxYPos = nan(1,length(rDataDirs));

    for ii=1:length(rDataDirs)
        posFname = fullfile(userConfig.subdir.rawDataDir,rDataDirs(ii).name,'tilePositions.mat');
        if ~exist(posFname,'file')
            continue
        end

        load(posFname,'positionArray')

        % Log the minimum X and Y positions
        out.minXPos(ii)=min(positionArray(:,5));
        out.minYPos(ii)=min(positionArray(:,6));

        out.maxXPos(ii)=max(positionArray(:,5));
        out.maxYPos(ii)=max(positionArray(:,6));


    end


    tileStepSizeMM = abs(mode(diff(positionArray(:,3))))


    tileExtentInMM = tileStepSizeMM  / (1-data.mosaic.overlapProportion);
 
    %out.minXY = [min(out.minXPos), min(out.minYPos)] - tileExtentInMM; %    % TODO -- I would have thought this is correct, but it seems not to be
    out.minXY = [min(out.minXPos), min(out.minYPos)] - tileStepSizeMM;
    out.maxXY = [max(out.maxXPos), max(out.maxYPos)];
