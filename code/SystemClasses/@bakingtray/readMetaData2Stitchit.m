function [out,sucessfulRead,rawOut]=readMetaData2Stitchit(obj,fname,verbose)
% For user documentation run "help readMetaData2Stitchit" at the command line


%Input argument error checking 
if nargin<2
    fname=obj.getTiledAcquisitionParamFile;
end

if ~exist(fname,'file')
    error('Can not find parameter file: %s',fname)
end

if nargin<3
    verbose=0;
end

%Read the TissueCyte mosaic file
rawOut=yaml.ReadYaml(fname,verbose);

if isstruct(rawOut)
    sucessfulRead=true;
else 
    sucessfulRead=false;
end

if ~sucessfulRead
    error('Failed to read %s',fname)
end
out = recipe2StitchIt(rawOut,fname);



%------------------------------------------------------------------------
function out = recipe2StitchIt(raw,fname)
%Convert the BakingTray recipe structure to a StitchIt structure

out.paramFileName=fname; %The name of the Mosaic file


%  Sample
out.sample = raw.sample;
out.sample.acqStartTime= raw.Acquisition.acqStartTime;
out.sample.activeChannels = raw.ScannerSettings.activeChannels;
out.mosaic = raw.mosaic;
out.tile =raw.Tile;
out.voxelSize=raw.VoxelSize;
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

return
%TODO: we need the stage locations
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