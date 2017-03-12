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
[rawOut,sucessfulRead]=obj.readMosaicMetaData(fname,verbose);

if ~sucessfulRead
    error('Failed to read %s',fname)
end

out = mosaic2StitchIt(rawOut,fname);

%TODO:
% Save the stitchit file to the current directory. But don't do it yet, because we need
% to be sure that the format of the file is as we want it to be. 




%------------------------------------------------------------------------
function out = mosaic2StitchIt(raw,fname)
%Convert the TissueCyte structure to a StitchIt structure

out.paramFileName=fname; %The name of the Mosaic file


%  Sample
out.sample.ID = raw.SampleID;
out.sample.acqStartTime = raw.acqDate; %convert from: '10/9/2015 10:10:49 AM'
out.sample.objectiveName='';
out.sample.excitationWavelength = raw.excwavelength; %depends on the user filling this in

if raw.channels==3
    out.sample.activeChannels=1:3;
elseif raw.channels==1
    out.sample.activeChannels=1;
end


%Mosaic
out.mosaic.sectionStartNum=raw.startnum; %The index of the first section
out.mosaic.numSections=raw.sections; %How many physical sections did the user ask for?
out.mosaic.sliceThickness=raw.sectionres; 
out.mosaic.numOpticalPlanes=raw.layers; %Number of optical sections per physical section
out.mosaic.overlapProportion=[];
out.mosaic.scanmode='tile';

% tile
% The number of columns and rows of voxels in each tile
out.tile.nRows=raw.rows;
out.tile.nColumns=raw.columns;


%  Voxel size
% We don't use the X and Y voxel size values from the Mosaic file. This is partly historical
% and partly practical. We instead use measured values stored in an INI file. A bit of a hack,
% but such is the TissueVision. 
userConfig=readStitchItINI;

micsPerPixScaleFactor = userConfig.micsPerPixel.numPix/out.tile.nRows; 
userConfig.micsPerPixel.micsPerPixelMeasured = userConfig.micsPerPixel.micsPerPixelMeasured * micsPerPixScaleFactor;
userConfig.micsPerPixel.micsPerPixelRows = userConfig.micsPerPixel.micsPerPixelRows * micsPerPixScaleFactor;
userConfig.micsPerPixel.micsPerPixelCols = userConfig.micsPerPixel.micsPerPixelCols * micsPerPixScaleFactor;

%Process the mics per pixel
if userConfig.micsPerPixel.usemeasured
    %If usemeasured is true, we use the measured value of mics per pixel from measuring with a grid.
    pixRes = [userConfig.micsPerPixel.micsPerPixel, userConfig.micsPerPixel.micsPerPixel];
else
    %Otherwise we use these tweaked values. 
    pixRes = [userConfig.micsPerPixel.micsPerPixelRows, userConfig.micsPerPixel.micsPerPixelCols];
end

out.voxelSize.X=pixRes(1); %x means along the direction of the x stage
out.voxelSize.Y=pixRes(2); %y means along the direction of the y stage
if raw.layers>1 %if we do optical sections, the separation is stored as a resolution
    out.voxelSize.Z=raw.zres*2;
else %if we didn't do optical sections, it is the separation between layers which is stored
    out.voxelSize.Z=raw.zres;
end


% NUMTILES 
%The number of tiles the system will take in x and y
out.numTiles.X=raw.mrows; %x means along the direction of the x stage
out.numTiles.Y=raw.mcolumns; %y means along the direction of the y stage


% TILESTEPSIZE
%The size of each tile step size
out.TileStepSize.X=raw.mrowres; %x means along the direction of the x stage
out.TileStepSize.Y=raw.mcolumnres; %y means along the direction of the y stage


% SYSTEM
out.System.ID=raw.ScannerID;
out.System.type='TissueCyte';
out.System.excitationLaserName='';


% SLICER
out.Slicer.frequency=raw.VibratomeFrequency;
out.Slicer.bladeApproachSPeed=raw.VibratomeStageSpeed;
out.Slicer.postCutDelay=raw.VibratomeDelay;
out.Slicer.cuttingSpeed=raw.SliceTranslationSpeed;


%Fill in the system specific fields
TVfields={'comments','Description','Pixrestime',...
        'PdTauFwd','PdTauRev','MCSkew','ScanRange','ScannerVScalar',...
        'TriggerLevel','ImageAdjFactor','ZdefaultVoltage','ZScanDirection',...
        'Zposition','ZWaitTime','Zscan'};

for ii=1:length(TVfields)
    out.systemSpecific.(TVfields{ii}) = raw.(TVfields{ii});
end

%X and Y stage positions
% The TissueCyte saves the stage positions in the section-specific mosaic files

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