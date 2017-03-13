function [im,index]=tileLoad(obj,coords,doIlluminationCorrection,doCrop,doPhaseCorrection)
% For user documentation run "help tileLoad" at the command line
% 
% This function works without the need for generateTileIndex

%TODO: abstract the error checking?

%COMMON
%Handle input arguments
if length(coords)~=5
    error('Coords should have a length of 5. Instead it has a length of %d', length(coords))
end

if nargin<3
    doIlluminationCorrection=[];
end

if nargin<4
    doCrop=[];  
end

if nargin<5
    doPhaseCorrection=[];
end

verbose=0; %Enable this for debugging. Otherwise it's best to leave it off


%Load the INI file and extract default values from it
userConfig=readStitchItINI;

if isempty(doIlluminationCorrection)
    doIlluminationCorrection=userConfig.tile.doIlluminationCorrection;
end

if isempty(doCrop)
    doCrop=userConfig.tile.docrop; 
end
if isempty(doPhaseCorrection)
    doPhaseCorrection=userConfig.tile.doPhaseCorrection;
end

averageSlowRows=userConfig.tile.averageSlowRows;



%Exit gracefully if data directory is missing 
param = readMetaData2Stitchit(getTiledAcquisitionParamFile);
sectionDir=fullfile(userConfig.subdir.rawDataDir, sprintf('%s-%04d',param.sample.ID,coords(1)));

if ~exist(sectionDir,'dir')
    fprintf('%s: No directory: %s. Skipping.\n',...
        mfilename,sprintf('%s',sectionDir))
    im=[];
    positionArray=[];
    index=[];
    return
end
%/COMMON



%Load tile index file or bail out gracefully if it doesn't exist. 
tileIndexFile=fullfile(sectionDir,'tileIndex');
if ~exist(tileIndexFile,'file')
    fprintf('%s: No tile index file: %s\n',mfilename,tileIndexFile)
    im=[];
    index=[];
    return
end



%Load the tile position array
load(fullfile(sectionDir, 'tilePositions.mat')); %contains variable positionArray



%Find the index of the optical section and tile(s)
%BT
%TODO: right now we have no optical sections. Eventually we will and these will likely 
%be accessed by file name.

indsToKeep=1:size(positionArray,1);

if coords(3)>0
    %TODO: get this working
    error('Can not handle coords(3)>0 right now')
    f=find(positionArray(:,2)==coords(3)); %Row in tile array
    positionArray = positionArray(f,:);
    indsToKeep=indsToKeep(f);
end

if coords(4)>0
    %TODO: get this working
    error('Can not handle coords(4)>0 right now')
    f=find(positionArray(:,1)==coords(4)); %Column in tile array
    positionArray = positionArray(f,:);
    indsToKeep=indsToKeep(f);
end
%/BT
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% TODO: loads of this will be common across systems and should be abstracted away
%       in fact, should probably use tiffstack at some point as this would work better
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


%So now build the expected file name of the TIFF stack
sectionNum = coords(1);
planeNum = coords(2);
channel = coords(5);

%TODO: we're just loading the full stack right now
im=[];

%Check that all requested data exist
for XYposInd=1:size(positionArray,1)
    sectionTiff = sprintf('%s-%04d_%05d_chn%d.tif',param.sample.ID,sectionNum,XYposInd,channel);
    path2stack = fullfile(sectionDir,sectionTiff);
    if ~exist(path2stack,'file') %TODO: bad 
        fprintf('%s - Can not find stack %s. RETURNING EMPTY DATA. BAD.\n', mfilename, path2stack);     
        im=[];
        positionArray=[];
        return
    end
end

%Load the last frame and pre-allocate the rest of the stack
XYposInd==1;
im=stitchit.tools.loadTiffStack(path2stack,'frames',planeNum,'outputType','int16');
im=repmat(im,[1,1,size(positionArray,1)]);
im(:,:,1:end-1)=0;

parfor XYposInd=1:size(positionArray,1)-1
    sectionTiff = sprintf('%s-%04d_%05d_chn%d.tif',param.sample.ID,sectionNum,XYposInd,channel);
    path2stack = fullfile(sectionDir,sectionTiff);
    
    %Load the tile and add to the stack
    im(:,:,XYposInd)=stitchit.tools.loadTiffStack(path2stack,'frames',planeNum,'outputType','int16'); %PRODUCES WEIRDLY LARGE NUMBERS. WHY??

end


expectedNumberOfTiles = param.numTiles.X*param.numTiles.Y;
if size(im,3) ~= expectedNumberOfTiles
    fprintf('\nERROR during %s -\nExpected %d tiles from file "%s" but loaded %d tiles.\nRETURNING EMPTY ARRAY FOR SAFETY\n',...
        mfilename, expectedNumberOfTiles, path2stack, size(im,3))
    im=[];
    index=[];
    return
end

%Load the tile stats data and pull out the empty tile threshold for this sample
tileStatsName = fullfile(sectionDir, 'tileStats.mat');
if exist(tileStatsName)
    load(tileStatsName); %contains variable tileStats
    emptyTileThresh = tileStats.emptyTileThresh(channel,planeNum);
    %so the empty tiles are:
    emptyTileIndexes = find(tileStats.mu{channel,planeNum}<=emptyTileThresh);
    if isempty(emptyTileIndexes)
        fprintf('%s failed to find empty tiles for %s channel %d plane %d. All have means of over %0.4f\n',...
            mfilename, sectionDir, channel, planeNum, emptyTileThresh)
    end
else
    emptyTileIndexes=[];
end

% The TIFFs we pull out of ScanImage will likely have negative numbers 
% in as we're trying to maximise the dynamic range. This will get 
% the numbers going from 0 to 2^12-1, but we maybe need a way determining
% for sure if this is needed. TODO: put into INI file?
% TODO: We should pull the DAQ range from the card and store it or the following may fail
im = im + 2^11-1; 
im = rot90(im,-1); 



%---------------
%Build index output so we are compatible with the TV version (for now)
index = ones(length(indsToKeep),8);
index(:,1) = indsToKeep;
index(:,2) = sectionNum;

%We flip the indexes around, because this is the order that the stitcher will expect
%and it uses these values to stitch
rowInd = positionArray(indsToKeep,2);
index(:,5) = abs(rowInd-max(rowInd))+1;

colInd = positionArray(indsToKeep,1);
index(:,4) = abs(colInd - max(colInd))+1;
%---------------
%/BT



%--------------------------------------------------------------------
%Begin processing the loaded image or image stack

%COMMON
%correctPhase delay if requested to do so
if doPhaseCorrection
    corrStatsFname = sprintf('%s%sphaseStats_%02d.mat',sectionDir,filesep,coords(2));
    if ~exist(corrStatsFname,'file')
        fprintf('%s. phase stats file %s missing. \n',mfilename,corrStatsFname)
    else
        load(corrStatsFname);
        phaseShifts = phaseShifts(indsToKeep);
        im = applyPhaseDelayShifts(im,phaseShifts);
    end
end


%Crop if requested to do so
if doCrop
    cropBy=round(size(im,1)*userConfig.tile.cropProportion); 
    if verbose
        fprintf('Cropping images by %d pixels on each size\n',crop)
    end
    im  = im(cropBy+1:end-cropBy, cropBy+1:end-cropBy, :);
end



%Remove the background (mean of the empty tiles)
if ~isempty(emptyTileIndexes) %zero very low values
    emptyTiles=im(1:10:end,1:10:end,emptyTileIndexes);
    offsetValue=mean(emptyTiles(:));
    im = im-offsetValue;
    im(im<0)=0;
else
    offsetValue=0;
    fprintf('%s found no empty tiles\n',mfilename)
end


%Do illumination correction if requested to do so %TODO: *REALLY* need this stuff abstracted elsewhere
if doIlluminationCorrection
    avDir = fullfile(userConfig.subdir.rawDataDir,userConfig.subdir.averageDir);

    if ~exist(avDir,'dir')
        fprintf('Please create grand averages with collateAverageImages\n')
    end

    aveTemplate = coords2ave(coords,userConfig);
    if doCrop
         aveTemplate = aveTemplate(cropBy+1:end-cropBy, cropBy+1:end-cropBy, :);
    end
    aveTemplate = aveTemplate-offsetValue;
    aveTemplate(aveTemplate<1)=1;

    if isempty(aveTemplate)
        fprintf('Illumination correction requested but not performed\n')
        return
    end

    if verbose
        fprintf('Doing %s illumination correction\n',userConfig.tile.illumCorType)
    end


    switch userConfig.tile.illumCorType %loaded from INI file

        case 'split'
            if averageSlowRows
                aveTemplate(:,:,1) = repmat(mean(aveTemplate(:,:,1),1), [size(aveTemplate,1),1]);
                aveTemplate(:,:,2) = repmat(mean(aveTemplate(:,:,2),1), [size(aveTemplate,1),1]);
            end

            %Divide by the template. Separate odd and even rows as needed       

            oddRows=find(mod(positionArray(:,2),2)); %Different from TV!
            if ~isempty(oddRows)
                im(:,:,oddRows)=stitchit.tools.divideByImage(im(:,:,oddRows),aveTemplate(:,:,2)); 
            end

            evenRows=find(~mod(positionArray(:,2),2)); %Different from TV!
            if ~isempty(evenRows)
                im(:,:,evenRows)=stitchit.tools.divideByImage(im(:,:,evenRows),aveTemplate(:,:,1));
            end
        case 'pool'
            aveTemplate = mean(aveTemplate,3);
            if averageSlowRows
                aveTemplate = repmat(mean(aveTemplate,1), [size(aveTemplate,1),1]);
            end
            im=stitchit.tools.divideByImage(im,aveTemplate);
        otherwise
            fprintf('Unknown illumination correction type: %s. Not correcting!', userConfig.tile.illumCorType)
    end


    % Again, remove the very low values after subtraction
    % TODO: this won't do anything if the offset value is very far from zero
    if ~isempty(emptyTileIndexes)
        emptyTiles=im(1:10:end,1:10:end,emptyTileIndexes);
        offsetValue=mean(emptyTiles(:));
        im(im<offsetValue)=0;
    end

end


%Calculate average filename from tile coordinates. We could simply load the
%image for one layer and one channel, or we could try odd stuff like averaging
%layers or channels. This may make things worse or it may make things better. 
function aveTemplate = coords2ave(coords,userConfig)

    layer=coords(2); % Optical section
    chan=coords(5);

    fname = sprintf('%s/%s/%d/%02d.bin',userConfig.subdir.rawDataDir,userConfig.subdir.averageDir,chan,layer);
    if exist(fname,'file')
        %The OS caches, so for repeated image loads this is negligible. 
        aveTemplate = loadAveBinFile(fname); 
    else
        aveTemplate=[];
        fprintf('%s Can not find average template file %s\n',mfilename,fname)
    end
    
%/COMMON