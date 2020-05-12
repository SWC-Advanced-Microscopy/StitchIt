function [out,sucessfulRead,rawOut]=readMetaData2Stitchit(fname,verbose)
% Read acquisition meta data into a MATLAB structure
%
% function [out,sucessfulRead]=readMetaData2Stitchit(fname,verbose)
%
% Purpose
% Read meta-data from a tiled acquisition parameter file and returns 
% mosaic meta data as a structure that StitchIt can handle. 
%
%
% Inputs
% fname - relative or absolute path to mosaic meta-data file.
% verbose - [optional, 0 by default] 
%
% 
% Outputs
% out - a structure containing the metadata
% sucessfulRead - 0 if the read failed for some reason. 1 otherwise.
% rawOut - the output of raw read (TODO: should get rid of this)
%
% The format of the meta-data is as follows. Below are shown only
% the fields that matter and really need to be there:
%
%  M.sample.ID - string defining the sample name
%  M.sample.objectiveName - string defining the objective name
%  M.sample.acqStartTime: e.g. '2017/03/07 16:09:04'
%  M.sample.activeChannels:  e.g. [1,3,4]
%  M.mosaic.sectionStartNum: 1
%  M.mosaic.numSections: 95
%  M.mosaic.sliceThickness: 100 (in microns)
%  M.mosaic.numOpticalPlanes: 3
%  M.mosaic.overlapProportion: 0.0700 (StitchIt calculates this for TissueVision data)
%  M.mosaic.scanmode: 'tile' (currently this is always "tile")
%  M.tile.nRows: 400 (num pixels per row in one tile)
%  M.tile.nColumns: 400 (num pixels per column in one tile)
%  M.voxelSize.X (in microns)
%  M.voxelSize.Y (in microns)
%  M.voxelSize.Z (in microns)
%  M.numTiles.X (number of tiles along X in the grid)
%  M.numTiles.Y (number of tiles along X in the grid)
%  M.TileStepSize.X - how far the stage moves in X between tile acquisitions in microns
%  M.TileStepSize.Y - how far the stage moves in Y between tile acquisitions in microns
%  M.System.ID - string defining the name of the acquisition system (used to read system-specific INI file)
%  M.System.type - string defining the type of system acquiring the data. e.g. TissueCyte, bakingtray, slidescanner, etc
%
%
%
% Developer Note:
% This function should avoid calling readStitchItINI in order to avoid recursion. 
% 
%
%
% Rob Campbell - Basel 2016


%Input argument error checking 
if nargin<1
    fname=getTiledAcquisitionParamFile;
end

if ~exist(fname,'file')
    error('Can not find parameter file: %s',fname)
end

if nargin<3
    verbose=0;
end


%Read the BakingTray "recipe" yml file
rawOut=stitchit.yaml.ReadYaml(fname,verbose);


if isstruct(rawOut)
    sucessfulRead=true;
else
    sucessfulRead=false;
end

if ~sucessfulRead
    error('Failed to read %s',fname)
end

% Turn the imported YAML data into a standardised StitchIt format. This 
% allows for potentially different acquisition systems to be "stitchable".
out = recipe2StitchIt(rawOut,fname);


% Add stage position data


%------------------------------------------------------------------------
% Internal functions follow. This is just for tidiness.

function out = recipe2StitchIt(raw,fname)
    %Convert the BakingTray recipe structure to a StitchIt structure

    out.paramFileName=fname; %The name of the Mosaic file


    %  Sample
    out.sample = raw.sample;
    out.sample.acqStartTime= raw.Acquisition.acqStartTime;
    out.sample.activeChannels = raw.ScannerSettings.activeChannels;
    out.mosaic = raw.mosaic;
    out.tile =raw.Tile;

    out.voxelSize=raw.StitchingParameters.VoxelSize; %Read from the user-tweaked settings.
    out.voxelSize.Z=raw.VoxelSize.Z; % The z is not tweaked
    out.lensDistort=raw.StitchingParameters.lensDistort;
    if isempty(out.lensDistort)
        out.lensDistort.rows=0;
        out.lensDistort.cols=0;
    end
    out.affineMat=cell2mat(raw.StitchingParameters.affineMat);
    out.numTiles = raw.NumTiles;
    out.TileStepSize = raw.TileStepSize;
    out.TileStepSize.X = 1E3 * out.TileStepSize.X; 
    out.TileStepSize.Y = 1E3 * out.TileStepSize.Y; 
    out.System = raw.SYSTEM;
    out.Slicer = raw.SLICER;

    %Ensure slice thickness is in microns
    if out.mosaic.sliceThickness<1
        out.mosaic.sliceThickness = out.mosaic.sliceThickness*1E3;
    end


function out = addStagePositions(recipeStruct,positionMatrix)
    % Add stage position data associated with each tile to the recipe file
    if ~isempty(raw.XPos)
        out.stageLocations.requestedStep.X = raw.XPos(:,1); %What was the motion step requested by the microscope?
        out.stageLocations.expected.X = cumsum(raw.XPos(:,1)); %Infer what the position shoudld be
        out.stageLocations.reported.X = raw.XPos(:,2);
    end

    if ~isempty(raw.YPos)
        out.stageLocations.requestedStep.Y = raw.YPos(:,1); %What was the motion step requested by the microscope?
        out.stageLocations.expected.Y = cumsum(raw.YPos(:,1)); %Infer what the position shoudld be
        out.stageLocations.reported.Y = raw.YPos(:,2);
    end