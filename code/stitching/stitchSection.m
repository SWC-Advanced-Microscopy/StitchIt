function varargout=stitchSection(section, channel, varargin)
% Stitch one or more sections of data from one channel
%
% function stitchSection(section, channel, 'param', 'val', ... )
%
% Purpose
% This function loads data to be stitched, pre-processes them as needed
% using previously saved parameters (comb correction, photobleach correction, 
% intensity correction, tile registration, etc). Stitching parameters that will
% remain fairly constant, such as tile overlap, are set via an INI file. 
%
% Saves the degree of down-scaling to a MAT file in the section root directory.
% Saves the original tile positions and sizes to a subdirectory as a CSV file.
% One CSV file per section. The data in these CSV files are BEFORE down-scaling. 
% 
%
% INPUTS (required)
% section -  1) a scalar (the z section in the brain). Stitches one plane only
%            2) a vector of length two [physical section, optical section]. Stitches one plane only
%            3) matrix defining the first and last planes to stitch:
%               [physSec1,optSec1; physSecN,optSecN]
%            4) a matrix defining a list of sections to stitch. one per row:
%               [physSec1,optSec1; physSec2,optSec2; ... physSecN,optSecN]
%            5) if empty, attempt to stitch from all available data directories
%
% channel - a scalar defining which channel to stitch.
% 
%
% INPUTS (optional param/value pairs)
% 'stitchedSize' - 100 (full size images) by default. If a number between 1 and 99 we save 
%                 a reduced version of the stack which has been resized by this amount. 
%                 e.g. if 50, we save a stack half the size. This is saved in a separate
%                 directory named accordingly. stitchedSize can be vector. Then we save a
%                 series of different resolutions. 
% 'overwrite'   - false by default. If false skips sections that have already been built. If true, overwrite.
% 'chessboard'  - false by default. if true do chessboard stitching (red/green overlapping tiles 
%                 to diagnose stitching quality) 
% 'bidishiftpixels' - zero by default. If non-zero, does a bidi correction shift by this whole number 
%                   of pixels. 
%
% OUTPUTS (optional)
% stitchedPlane - If only one section was requested to be stitched then it's possible to return it
%                 it as an output instead of saving to disk. If an output is requested nothing is
%                 is written to disk.
% metaData - the meta-data from the acquisition system used to stitch the image. Includes stitching inParams.
%
%
% EXAMPLES
%
% 1. Stitch section 124 channel 1
% >> stitchSection(124, 1)   
%
% 2. Stitch physical section 34, optical section 5, channel 1, and make both full size 
%    and 25% size images. 
% >> stitchSection([34,5], 1, 'stitchedSize', [100,25]) 
%
%
% 3. Stitch starting at physical section 1, optical section 1 and finishing  
%    at section 120, layer 8, channel 2, with full size and 25% size images.
% >> stitchSection([1,1; 120,8], 2, 'stitchedSize',[100,25]) 
%
% 4. Stitch section 100 channel 2 with chessboard stitching
% >> stitchSection(100, 2, 'chessboard', true)   
%
%
% Rob Campbell - Basel 2014
%
% See also - stitcher, stitchAllSections, gridPos2Pixels


%Parse non-optional input arguments
if nargin<2
    error('At least two input arguments needed')
end

if size(section,2)>2
    error('Section must be a scalar or an N by 2 array')
end

%Handle section argument
if size(section,1)<=2 
    section=handleSectionArg(section);
end

if length(channel)>1
    error('Channel must be a scalar')
end

if ~isnumeric(channel)
    error('Channel must be numeric')
end


% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
%Parse optional arguments
inParams = inputParser;
inParams.CaseSensitive = false;
inParams.addParameter('stitchedSize', 100, @(x) isnumeric(x));
inParams.addParameter('overwrite', false, @(x) islogical(x) || x==0 || x==1);
inParams.addParameter('chessboard', false, @(x) islogical(x) || x==0 || x==1);
inParams.addParameter('bidishiftpixels', 0)
inParams.parse(varargin{:});

stitchedSize=inParams.Results.stitchedSize;
overwrite=inParams.Results.overwrite;
doChessBoard=inParams.Results.chessboard;
bidishiftpixels = inParams.Results.bidishiftpixels;

% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


param=readMetaData2Stitchit;
[userConfig,fullPathToINIfile]=readStitchItINI;

%Do not proceeed if stitching will fill the disk

%TODO: the following assumes a regular grid of tiles. 
%if data weren't acquired this way, send a warning to screen.
bytesPerTile = param.tile.nRows * param.tile.nColumns * 2; %assume 16 bit images
bytesPerTile = bytesPerTile * (stitchedSize/100)^2; %Scale by the resize ratio
MBPerPlane = bytesPerTile * param.numTiles.X * param.numTiles.Y * 1024^-2; %This is generous, we ignore tile overlap


if nargout>0 
    if size(section,1)==1
        outputMatrixOnly=true;
    else
        fprintf('Only one section can be returned as an output at the moment\n')
        return
    end
else
    outputMatrixOnly=false;
end


%Calculate GB to be used based on number of sections
if ~outputMatrixOnly
    nSections = size(section,1);
    GBrequired= nSections * MBPerPlane / 1024;

    fprintf('Producing %d stitched images from channel %d. This will consume %0.2f GB of disk space.\n',...
        nSections, channel, GBrequired )

    spaceUsed=stitchit.tools.returnDiskSpace;
    if  GBrequired > spaceUsed.freeGB 
        fprintf('\n ** Not enough disk space to stitch these sections. You have only %d GB left!\n ** %s is aborting\n\n',...
            round(spaceUsed.freeGB), mfilename)
        return
    end
end


%Extract preferences from INI file structure
doIlluminationCorrection = userConfig.tile.doIlluminationCorrection; %correct tile illumination on loading. 
doPhaseCorrection        = userConfig.tile.doPhaseCorrection;        %If 1, use saved coefficients to correct comb artifact
doStageCoords            = userConfig.stitching.doStageCoords;       %If 1 use stage coords instead of naive coords

%set up chessboard stitching (which is also the fusion weight variable that currently isn't interesting)
if doChessBoard==1
    fusionWeight=-1;
else
    fusionWeight=userConfig.stitching.fusionWeight;
end


baseName=directoryBaseName; %the directory base name

%Report stitching options to screen. Particularly important to do as long as 
fprintf(' Stitching parameters:\n')
fprintf('Illumination correction: %d\n', doIlluminationCorrection)
fprintf('Phase (comb) correction: %d\n', doPhaseCorrection)
if fusionWeight<0
    fprintf('Doing chessboard stitching\n')
end
fprintf('--------------------------------\n\n')


%Create directories we will use for saving the stitched data
for ii=1:length(stitchedSize)

    thisSize = stitchedSize(ii);
    reducedSizeDir{ii} = sprintf('%s_%03d', userConfig.subdir.stitchedDirBaseName, thisSize);
    if outputMatrixOnly, continue, end
    if ~exist(reducedSizeDir{ii},'dir')
        fprintf('Creating empty stitched data directory tree: %s\n', reducedSizeDir{ii})
        mkdir(reducedSizeDir{ii})
    end
        thisChan=sprintf('%s%s%d',reducedSizeDir{ii},filesep,channel);

    %The details directory stores tile position files
    if ~exist([thisChan,filesep,'details'],'dir')
        mkdir([thisChan,filesep,'details']) 
    end
end

% Get the exent of the imaged area if we are to use stage positions
voxelSize = [param.voxelSize.X,param.voxelSize.Y];
if doStageCoords==1 || strcmp(param.mosaic.scanmode, 'tiled: auto-ROI')
    imagedExtent = determineStitchedImageExtent;
    maxXY = max(stagePos2PixelPos([imagedExtent.minXY;imagedExtent.maxXY],voxelSize));
else
    imagedExtent.maxXY = [];
    maxXY=[];
end

numStitched=0; %The number of images stitched. This is just used for error checking
varargout=cell(1,1); %Declare outside parfor so they are returned correctly
nout=nargout;

parfor ii=1:size(section,1) %Tile loading is done in parallel, but it still seems faster to stitch in parallel
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    %Explicitly clear these variables so as not get annoying warnings
    naiveWidth=[];
    naiveHeight=[];
    trimPixels=[];

    %The physical section and optical section
    thisSection=section(ii,:);


    %Skip if data have already been created 
    filesExist=zeros(1,length(reducedSizeDir)); %we use this again below to only write data as needed

    if ~overwrite && ~outputMatrixOnly
        for thisR = 1:length(reducedSizeDir)
            fname = sprintf('.%s%s%s%d%ssection_%03d_%02d.tif',...
                                        filesep,reducedSizeDir{thisR},filesep, channel, filesep,thisSection);
            if exist(fname, 'file')
                filesExist(thisR)=1;
            end
        end
        if all(filesExist)
            fprintf('Files exist SKIPPING %03d/%03d -- Section %03d/%02d\n',ii,size(section,1),thisSection)
            continue
        end
    end


    [imStack,tileIndex,stagePos]=tileLoad([thisSection,0,0,channel],'bidishiftpixels',bidishiftpixels);

    if isempty(imStack) %Skip if the image stack is empty. 
        fprintf('Skipping %03d/%02d due to missing tiles\n',thisSection)
        continue
    end

    fprintf('Stitching %03d/%03d -- Section %03d/%02d\n',ii,size(section,1),thisSection)

    tileIndex=tileIndex(:,4:5); %Keep only the columns we're interested in


    %Either stitch based on naive tile positions or stage coordinates. 
    if doStageCoords == 1
        posArray = [stagePos.actualPos.X,stagePos.actualPos.Y];
        pixelPositions = stagePos2PixelPos(posArray,voxelSize,imagedExtent.maxXY);

    elseif doStageCoords == 0
        posArray = [stagePos.targetPos.X,stagePos.targetPos.Y];
        pixelPositions = stagePos2PixelPos(posArray,voxelSize,imagedExtent.maxXY);
    else
        % We use the tile grid positions. This is how we used to do stitching before May 2020. 
        % the doStageCoords == 0 should give a result identical to this
        fprintf('Basing stitching on tile grid on position array coordinates\n')
        pixelPositions = ceil(gridPos2Pixels(tileIndex,voxelSize));
    end

    % maxXY a value in pixels which is calculated above and derived from the function determineStitchedImageExtent
    [stitched,tilePosInPixels]=stitcher(imStack,pixelPositions,fusionWeight,maxXY);


    %Save full and reduced size planes
    for thisR = 1:length(reducedSizeDir)
        if outputMatrixOnly
            % So nothing is saved
            continue
        end
        % Don't save if files exist or the user asked for an output argument
        if filesExist(thisR) || outputMatrixOnly
            continue
        end

        sectionDir = sprintf('.%s%s%s%d%s',filesep,reducedSizeDir{thisR},filesep, channel, filesep);
        sectionFname = sprintf('%ssection_%03d_%02d.tif',sectionDir,thisSection);

        if userConfig.stitching.saveCompressedStitched == true
            imwrite(imresize(stitched,stitchedSize(thisR)/100),sectionFname,'Compression','lzw' )
        else
            imwrite(imresize(stitched,stitchedSize(thisR)/100),sectionFname,'Compression','None' )
        end

        %also save the tile positions
        tilePosFname = sprintf('%sdetails%stilePos_%03d_%02d.csv',sectionDir,filesep,thisSection);
        stitchit.tools.saveMatrixAsCSV(tilePosInPixels,tilePosFname,'x,xwidth,y,ywidth'); %todo: save as binary instead for speed?
    end

    numStitched=numStitched+1;

    % This needs to be here so we return "stitched" from the parfor loop
    if outputMatrixOnly && nout>0
        varargout{ii}=stitched;
    end
end


if numStitched==0
    fprintf('\nNo images stitched by %s\n',mfilename);
    return
end

if outputMatrixOnly
    if nargout>1
        varargout{2}=param;
    end
    % Returns regardless of whether nargout == 1 or == 2
    return
end

%Report back if image sizes aren't all equal for the largest images
[~,ind]=max(stitchedSize);
sectionDir = sprintf('.%s%s%s%d%s',filesep,reducedSizeDir{ind},filesep, channel, filesep);
if checkStitchedImageSizes(sectionDir)>0
    fprintf('WARNING! Stitched images are not all the same size!\n')
end



%Finally, write the stitching parameters to the directory. 
iniFileContents=showStitchItConf(-1,fullPathToINIfile);

for thisR = 1:length(reducedSizeDir)
        fname = sprintf('.%s%s%s%d%sstitchingParams.ini',...
                                filesep,reducedSizeDir{thisR},filesep, channel, filesep);

        fprintf('Logging stitching parameters to %s\n',fname)

        fid = fopen(fname,'w+');
        fprintf(fid,'%s',iniFileContents);
        fclose(fid);

        %Be extra careful and save the reduced file size
        thisStitchedSize = stitchedSize(thisR);
        fname = sprintf('.%s%s%s%d%sstitchedSize.mat',...
                                filesep,reducedSizeDir{thisR},filesep, channel, filesep);

        save(fname,'thisStitchedSize')
end
