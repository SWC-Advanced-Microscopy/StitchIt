function [im,index]=tileLoad(obj,coords,doIlluminationCorrection,doCrop,doCombCorrection)
% For user documentation run "help tileLoad" at the command line
% 
% This function works without the need for generateTileIndex

%TODO: abstract the error checking?

%COMMON
%Handle input arguments


if length(coords)~=5
    % coords - a vector of length 5 4 with the fields:
    %     [physical section, optical section, yID, xID,channel]
    error('Coords should have a length of 5. Instead it has a length of %d', length(coords))
end

if nargin<3
    doIlluminationCorrection=[];
end

if nargin<4
    doCrop=[];  
end

if nargin<5
    doCombCorrection=[];
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
if isempty(doCombCorrection)
    doCombCorrection=userConfig.tile.doPhaseCorrection;
end

averageSlowRows=userConfig.tile.averageSlowRows;



%Exit gracefully if data directory is missing 
param = readMetaData2Stitchit;
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
planeNum = coords(2); %Optical plane
channel = coords(5);

%TODO: we're just loading the full stack right now
im=[];


%Check that all requested data exist
for XYposInd=1:size(positionArray,1)
    sectionTiff = sprintf('%s-%04d_%05d.tif',param.sample.ID,sectionNum,XYposInd);
    path2stack = fullfile(sectionDir,sectionTiff);
    if ~exist(path2stack,'file') %TODO: bad [why? -- RAAC 02/05/2017]
        fprintf('%s - Can not find stack %s. RETURNING EMPTY DATA. BAD.\n', mfilename, path2stack);
        im=[];
        index=[];
        positionArray=[];
        return
    end
end


% Check that the user has asked for a channel that exists
imInfo = imfinfo(path2stack);
SI=obj.parse_si_header(imInfo(1),'Software'); % Parse the ScanImage TIFF header

channelsInSIstack = SI.channelSave;
numChannelsAvailable = length(channelsInSIstack);

if ~any(SI.channelsActive == channel)
    availChansStr = repmat('%d ', length(channelsInSIstack) );
    fprintf(['ERROR: tileLoad is attempting to load channel %d but this does not exist. Available channels: ', availChansStr, '\n'], ...
        channel, channelsInSIstack)
    return
end


%Load the last frame and pre-allocate the rest of the stack
XYposInd==1;
im=stitchit.tools.loadTiffStack(path2stack,'frames',planeNum,'outputType','int16');
im=repmat(im,[1,1,size(positionArray,1)]);
im(:,:,1:end-1)=0;

parfor XYposInd=1:size(positionArray,1)-1
    sectionTiff = sprintf('%s-%04d_%05d.tif',param.sample.ID,sectionNum,XYposInd);
    path2stack = fullfile(sectionDir,sectionTiff);

    % The ScanImage stack contains multiple channels per plane 
    planeInSIstack =  numChannelsAvailable*(planeNum-1) + find(channelsInSIstack==channel);

    %Load the tile and add to the stack
    im(:,:,XYposInd)=stitchit.tools.loadTiffStack(path2stack,'frames',planeInSIstack,'outputType','int16'); %TODO: check -- this used to produce weirdly large numbers. Maybe it doesn't any more?

end


expectedNumberOfTiles = param.numTiles.X*param.numTiles.Y;
if size(im,3) ~= expectedNumberOfTiles
    fprintf('\nERROR during %s -\nExpected %d tiles from file "%s" but loaded %d tiles.\nRETURNING EMPTY ARRAY FOR SAFETY\n',...
        mfilename, expectedNumberOfTiles, path2stack, size(im,3))
    im=[];
    index=[];
    return
end

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

%correct phase delay (comb artifact) if requested to do so
if doCombCorrection
    im = stitchit.tileload.combCorrector(im,sectionDir,coords,userConfig);
end


%Do illumination correction if requested to do so
if doIlluminationCorrection 
    im = stitchit.tileload.illuminationCorrector(im,coords,userConfig,index,verbose);
end


%Crop if requested to do so
if doCrop
    im = stitchit.tileload.cropper(im,userConfig,verbose);
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