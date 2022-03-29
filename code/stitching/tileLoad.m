function [im,index,stagePos]=tileLoad(coords,varargin)
% Load raw tile data as a stack for processing by StitchIt
%
% function [im,index]=tileLoad(coords,'Param1', Val1, 'Param2', Val2, ...)
%
% PURPOSE
% Load either a single tile from a defined section, optical section, and channel,
% or load a whole tile (all TIFFs) from a defined section, optical section, 
% and channel. 
%
%
% INPUTS (required)
% coords - a vector of length 5 4 with the fields:
%     [physical section, optical section, yID, xID,channel]
%
% All indecies start at 1. If yID or xID is zero we load the optical slice. 
% e.g. To load all tiles from section 10, optical section 3, channel 1 we do:
%    [10,3,0,0,1]. Note that if you have only one optical section
%    per physical section then you still need to do: [10,1,0,0,1]
%
%
% INPUTS (optional, for advanced users)
% doIlluminationCorrection - By default do what's defined in the INI file. Otherwise 
%                            this may be true (apply correction) or false (do not apply correction).
% doCrop - By default crop all four edges by the value defined in the INI file.
%          If cropBy is false, no cropping is performed. If true it is performed.
% doPhaseCorrection - Apply pre-loaded phase correction. If false don't apply. If true apply.
%                     By default do what is specified in the INI file.
% verbsose - false by default. If true, debug information is printed to screen.  
%
% doSubtractOffset - Apply offset correction to raw images. If false don't apply. If true apply 
%                    (if possible to apply). Otherwise do what is in INI file.
%                    If the offset correction was used to calculate the average tiles then it is 
%                    integrated into these averages. So you might get odd results if you choose
%                    disable the offset correction and use average tiles that include it. Under
%                    these circumstances you might want to re-generate the average images. 
%                    Equally, if the offset was not calculated then it's not incorporated into the 
%                    average and the offset value will be forced to be zero. So the doSubtractOffset
%                    value will have no effect in this case. if doSubtractOffset is -1 the the offset
%                    is multiplied by -1 before being subtracted.
% bidishiftpixels - zero by default. If non-zero, does a bidi correction shift by this whole number 
%                   of pixels. 
%
%
% OUTPUTS
% im - The image or image stack at 16 bit unsigned integers.
% index - The index data of each tile allowing the locations
%         of the tiles in the mosaic to be determined:
%
% 1. file index
% 2. z-section index
% 3. optical section
% 4. tile row
% 5. tile column
% 
% stagePos - structure containing stage positions in mm
%
%
% EXAMPLES
% >> T=tileLoad([1,1,0,0,3]);
% >> T=tileLoad([1,1,0,0,3],'doCrop',false);
%
%
%
% Rob Campbell - Basel 2014
%               updated to handle param/value pairs - Basel 2017



if length(coords)~=5
    % coords - a vector of length 5 with the fields:
    %     [physical section, optical section, yID, xID,channel]
    error('Input argument "coords" should have a length of 5. Instead it has a length of %d', length(coords))
end


% Parse optional inputs
IN = inputParser;
IN.CaseSensitive = false;

valChk = @(x) islogical(x) || x==0 || x==1 || isempty(x) || x==-1;
IN.addParameter('doIlluminationCorrection', [], valChk);
IN.addParameter('doCrop', [], valChk);
IN.addParameter('doCombCorrection', [], valChk);
IN.addParameter('doSubtractOffset', [], valChk);
IN.addParameter('bidishiftpixels', 0, @(x) isscalar(x) && mod(x,1) == 0)
IN.addParameter('verbose', false, @(x) islogical(x) || x==0 || x==1 );

IN.parse(varargin{:});

doIlluminationCorrection = IN.Results.doIlluminationCorrection;
doCrop = IN.Results.doCrop;
doCombCorrection = IN.Results.doCombCorrection;
doSubtractOffset = IN.Results.doSubtractOffset;
verbose = IN.Results.verbose;
bidishiftpixels = IN.Results.bidishiftpixels;


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

if isempty(doSubtractOffset)
    doSubtractOffset=userConfig.tile.doOffsetSubtraction;
end


%Exit gracefully if data directory is missing 
param = readMetaData2Stitchit;
sectionDir=fullfile(userConfig.subdir.rawDataDir, sprintf('%s-%04d',param.sample.ID,coords(1)));


% To exit gracefully if data are missing
im=[];
stagePos=[];
index=[];

if ~exist(sectionDir,'dir')
    fprintf('%s: No directory: %s. Skipping.\n', mfilename,sprintf('%s',sectionDir))
    return
end



%Load the tile position array
posFname = fullfile(sectionDir,'tilePositions.mat');
if ~exist(posFname,'file')
    fprintf('tileLoad fails to find tile position file at %s\n',posFname)
    return
end
load(posFname); %contains variable positionArray



%Find the index of the optical section and tile(s)
indsToKeep=1:size(positionArray,1);

if coords(3)>0
    f=find(positionArray(:,2)==coords(3)); %Row in tile array
    positionArray = positionArray(f,:);
    indsToKeep=indsToKeep(f);
end

if coords(4)>0
    f=find(positionArray(:,1)==coords(4)); %Column in tile array
    positionArray = positionArray(f,:);
    indsToKeep=indsToKeep(f);
end


%So now build the expected file name of the TIFF stack
sectionNum = coords(1);
planeNum = coords(2); %Optical plane
channel = coords(5);


%Check that all requested data exist
for XYposInd=1:length(indsToKeep)
    sectionTiff = sprintf('%s-%04d_%05d.tif',param.sample.ID,sectionNum,indsToKeep(XYposInd));
    path2stack = fullfile(sectionDir,sectionTiff);
    if ~exist(path2stack,'file')
        fprintf('%s - Can not find stack %s. RETURNING EMPTY DATA. BAD.\n', mfilename, path2stack);
        return
    end
end


% Check that the user has asked for a channel that exists
imInfo = imfinfo(path2stack);
SI=stitchit.tools.parse_si_header(imInfo(1),'Software'); % Parse the ScanImage TIFF header

channelsInSIstack = SI.channelSave;
numChannelsAvailable = length(channelsInSIstack);



if ~any(SI.channelsActive == channel)
    availChansStr = repmat('%d ', [1, length(channelsInSIstack)] );
    fprintf(['ERROR: tileLoad is attempting to load channel %d but this does not exist. Available channels: ', availChansStr, '\n'], ...
        channel, channelsInSIstack)
    return
end

% Check that the user has asked for an optical plane that exists
if planeNum>SI.numFramesPerVolume
    fprintf('ERROR: tileLoad is attempting to load plane %d but this does not exist. There are %d available planes\n',...
        planeNum,SI.numFramesPerVolume)
    return
end


%Load the last frame and pre-allocate the rest of the stack
im=stitchit.tools.loadTiffStack(path2stack,'frames',planeNum,'outputType','int16');
im=repmat(im,[1,1,size(positionArray,1)]);
im(:,:,1:end-1)=0;

parfor XYposInd=1:length(indsToKeep)

    sectionTiff = sprintf('%s-%04d_%05d.tif',param.sample.ID,sectionNum,indsToKeep(XYposInd) );
    path2stack = fullfile(sectionDir,sectionTiff);

    % The ScanImage stack contains multiple channels per plane 
    planeInSIstack =  numChannelsAvailable*(planeNum-1) + find(channelsInSIstack==channel);

    %Load the tile and add to the stack
    im(:,:,XYposInd)=stitchit.tools.loadTiffStack(path2stack,'frames',planeInSIstack,'outputType','int16');
end

% If this is not an auto-ROI acquisition and we have the wrong number of tiles, do not load any
if ~strcmp(param.mosaic.scanmode, 'tiled: auto-ROI')
    expectedNumberOfTiles = param.numTiles.X*param.numTiles.Y;
    if size(im,3) ~= expectedNumberOfTiles && coords(3)==0 && coords(4)==0
        fprintf('\nERROR during %s -\nExpected %d tiles from file "%s" but loaded %d tiles.\nRETURNING EMPTY ARRAY FOR SAFETY\n',...
            mfilename, expectedNumberOfTiles, path2stack, size(im,3))
        im=[];
        index=[];
        return
    end
end



%---------------
%Build index output so we are compatible with the TV version (for now)
index = ones(length(indsToKeep),5);

index(:,1) = indsToKeep;
index(:,2) = sectionNum;

%We flip the indexes around, because this is the order that the stitcher will expect
%and it uses these values to stitch

rowInd = positionArray(:,2);
index(:,5) = abs(rowInd-max(rowInd))+1;

colInd = positionArray(:,1);
index(:,4) = abs(colInd - max(colInd))+1;
%---------------
%/BT

if doIlluminationCorrection==-1
    return
end




%--------------------------------------------------------------------
%Begin processing the loaded image or image stack

%correct phase delay (comb artifact) if requested to do so
if doCombCorrection
    disp('comb correction not re-implemented yet!')
    %im = stitchit.tileload.combCorrector(im,sectionDir,coords,userConfig);
end



% If requested and possible, subtract the calculated offset from the tiles.
if doSubtractOffset==1
    offset = stitchit.tools.getOffset(coords);
    if ~isempty(offset) && isa(im,'int16')
        % We will save 16 bit unsigned TIFFs and will need, sadly, to transiently convert to singles
        % if the data are saved as signed 16 bit tiffs.
        offset = single(offset);
        im = uint16(single(im) - offset);
    else
        fprintf('\n\nWARNING: %s finds save data are of class %s. Not subtracting offset\n. Contact developer!\n\n', ...
            mfilename, class(im))
    end

end

%Do illumination correction if requested to do so
if doIlluminationCorrection 
    im = stitchit.tileload.illuminationCorrector(im,coords,userConfig,index,verbose);
end



% This is a super simple way for correcting bidirectional scanning artifacts with a resonant scanner.
if bidishiftpixels ~= 0
  d = im(1:2:end,:,:);
  d = circshift(d,[0,bidishiftpixels,0]);
  im(1:2:end,:,:) = d;
end


%Perform any required image manipulations
LD = param.lensDistort;
im = stitchit.tools.lensdistort(im, [LD.rows, LD.cols],'affineMat',param.affineMat);


%Rotate if needed to allow for stitching
im = rot90(im,userConfig.tile.tileRotate); 

if userConfig.tile.tileFlipLR==1
  im = fliplr(im);
end


%Crop if requested to do so
if doCrop
    im = stitchit.tileload.cropper(im,userConfig,verbose);
end


% get stage positions if requested
if nargout>2
    stagePos.targetPos.X = positionArray(:,3);
    stagePos.targetPos.Y = positionArray(:,4);
    stagePos.actualPos.X = positionArray(:,5);
    stagePos.actualPos.Y = positionArray(:,6);
end
