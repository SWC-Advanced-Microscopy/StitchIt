function varargout = generateTileIndex(obj,sectionDir,forceOverwrite,verbose)
% Index all raw data tiles in a TV experiment, link original file names to position in tile array 
%
% function nCompleted = generateTileIndex(sectionDir,forceOverwrite,verbose)
% 
% For user documentation run "help generateTileIndex" at the command line


%Check input args
if nargin < 2 | isempty(sectionDir)
    sectionDir=[];
end
if nargin < 3 | isempty(forceOverwrite)
    forceOverwrite=0;
end
if nargin<4
    verbose=1;
end

userConfig=readStitchItINI;

if ~exist(userConfig.subdir.rawDataDir,'dir')
    error('Can not find raw data directory: .%s%s',filesep,userConfig.subdir.rawDataDir)
end


mosaicFile=getTiledAcquisitionParamFile;
[data,successfulRead]=readMetaData2Stitchit(mosaicFile);
if ~successfulRead
    fprintf('failed to read all tiles from %s\n',mosaicFile)
    if nargout>0
        varargout{1}=0;
    end

    return
end


if verbose
    %Report experiment details to screen
    fprintf(['\nFound experiment with the following parameters:\n',...
         ' Image size: %d^2\n',...
         ' Expected final number of physical sections: %d\n',...
         ' Section thickness: %d\n',...
         ' Optical sections: %d\n',...
         ' Tiles: %d by %d \n'],...
         data.tile.nRows, data.mosaic.numSections, data.mosaic.sliceThickness,...
         data.mosaic.numOpticalPlanes, data.numTiles.X, data.numTiles.Y)
end


%Find the raw directories we will descend into. 
if isempty(sectionDir)
    baseName=directoryBaseName(mosaicFile);
    sectionDirectories=dir(fullfile(userConfig.subdir.rawDataDir,[baseName,'*']));
else
    indexPresent=generateIndexFileInDirectory(obj,sectionDir,forceOverwrite,userConfig);
    if nargout>0
        varargout{1}=sum(indexPresent);
    end
    if nargout>1
        varargout{2}=indexPresent;
    end

    return
end


if isempty(sectionDirectories)
    error('Can not find any raw data directories')
else
    if verbose
        fprintf('\nFound %d raw data directories\n', length(sectionDirectories))
    end
end


% Generate tile index file. 
if verbose
    G=gcp;
    tic
    fprintf('\nGenerating tile index files using %d threads\n', G.NumWorkers)
end

indexPresent=ones(1,length(sectionDirectories));

%Loop through all section directories
parfor thisDir = 1:length(sectionDirectories)
    indexPresent(thisDir)=generateIndexFileInDirectory(obj,sectionDirectories(thisDir).name,forceOverwrite,userConfig);
end %parfor thisDir = 1:length(sectionDirectories)


if verbose
    fprintf('Indexes generated in %0.1f s\n', toc )
end

%Handle output arguments
if nargout>0
    varargout{1}=sum(indexPresent);
end
if nargout>1
    varargout{2}=indexPresent;
end



% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
function indexPresent=generateIndexFileInDirectory(obj,dirName,forceOverwrite,userConfig)
% Generates index and returns 1 if index was generated or is already present. 
% 0 otherwise, indicating that index can not be built (e.g. directory partially full)

%Skip if the file has already been written
tileIndexFname = fullfile(userConfig.subdir.rawDataDir,dirName,'tileIndex');
if ~forceOverwrite & exist(tileIndexFname)
    indexPresent=1;
    return
end

%Read section param file if it's there. Otherwise bail out. 
[~,sectionDir]=fileparts(dirName); 
config=readStitchItINI;
paramFname=fullfile(config.subdir.rawDataDir,dirName,['Mosaic_',sectionDir,'.txt']);

if ~exist(paramFname,'file') 
    fprintf('No mosaic file %s found\n',paramFname)
    indexPresent=0;
    return
end

[param,successfulRead] = readMetaData2Stitchit(paramFname);
if ~successfulRead
    fprintf('WARNING: failed to read meta data properly. skipping %s\n',dirName)
    indexPresent=0;
    return
end


nImages = param.numTiles.X * param.numTiles.Y; %The number of images in one optical section from one channel

%Skip directory if it doesn't contain the expected number of images
tifPrefix = obj.acqDate2TifPrefix(param.sample.acqStartTime);
d=dir([userConfig.subdir.rawDataDir,filesep,dirName,filesep,tifPrefix,'*']);
if length(d)==0 %There may have been a mis-match between the Mosaic file time and date and the file names
    indexPresent=0;
    fprintf('Unable to find tiff files\n');
    return
end

if mod(length(d),nImages*param.mosaic.numOpticalPlanes)~=0
    fprintf('%s: %s does not contain the expected number of images. Found %d expected a multiple of %d. SKIPPING\n',mfilename,dirName,length(d),nImages*param.mosaic.numOpticalPlanes)
    indexPresent=0;
    return
end


%Pre-allocate arrays
fileIndex = nan(nImages,1); %The index of the file
tileXID = nan(nImages,1); 
tileYID = nan(nImages,1);

%Default values for the first tile
tileXID(1) = 1; %Columns
tileYID(1) = 1; %Rows

%Get the section number from the directory name
tok=regexp(dirName,'.*-(\d{4})','tokens');
sectionNumber=str2num(tok{1}{1});



if ~isfield(param,'stageLocations')
    fprintf('\n *** %s should contain a stage location field but it does not.\n *** Something is wrong with the data in directory %s. SKIPPING\n\n',...
        paramFname,dirName)
    indexPresent=0;
    return
end

%Attempt to catch this error, but still not sure where it comes from (TODO)
if nImages>length(param.stageLocations.requestedStep.X)
    fprintf('%s: length "stageLocations.requestedStep.X" is smaller than the number of images. SKIPPING\n',dirName)
    indexPresent=0;
    return
end

%Go through and make a skeleton set of numbers for one optical section 
for iImage = 1:nImages

    if iImage > 1

        %Note we effectively transposing the coordinates here
        if param.stageLocations.requestedStep.X(iImage) > 0
            tileYID(iImage) = tileYID(iImage-1) + 1;
        elseif param.stageLocations.requestedStep.X(iImage) < 0
            tileYID(iImage) = tileYID(iImage-1) - 1;
        else
            tileYID(iImage) = tileYID(iImage-1);
        end

        if param.stageLocations.requestedStep.Y(iImage) > 0
            tileXID(iImage) = tileXID(iImage-1) + 1;
        elseif param.stageLocations.requestedStep.Y(iImage) < 0
            tileXID(iImage) = tileXID(iImage-1) - 1;
        else 
            tileXID(iImage) = tileXID(iImage-1);
        end

    end %if iImage < 1 

    fileIndex(iImage) = param.mosaic.sectionStartNum + (iImage - 1) ;
end



%Make each tile Y location have a unique scalar ID that starts at 1 (so fix anything that has negative numbers)
%TODO: figure out why I had to switch from the uncommented line to the commented
%tileYID = absflipud(tileYID);
tileYID = abs(tileYID-max(tileYID))+1;

if any(tileXID<0)
    %It's very unlikely this line will ever need to run. If it does, the likely something is wrong.
    %If so, we report to screen that this happened
    fprintf('Running  tileXID = abs(tileXID-max(tileXID))+1; in %s. This is unusual. Check your images\n',mfilename)
    tileXID = abs(tileXID-max(tileXID))+1;
end



%Now loop through the optical sections to make an array that links each file index to an 
%a position in the array and an optical section. We have to do this because when the acquisition
%software fails to acquire a tile it also screws up the file indexing. 

fid=fopen(tileIndexFname,'w+');
fwrite(fid,8,'uint32'); %The number of ints in one row

for thisLayer = 1:param.mosaic.numOpticalPlanes  %Iterate over optical sections within this physical section
    for ii = 1:nImages %Loop through the number files in an optical section

           %The y, x, and z position of the tile in the whole volume (all physical sections)
           thisTileYID = tileYID(ii);
           thisTileXID = tileXID(ii);
           thisTileZID   = param.mosaic.numOpticalPlanes * (sectionNumber-1) + thisLayer; 

        thisFileIndex = fileIndex(ii) + nImages*(thisLayer-1); %The index of this tile


        %Now we build the line for the look up file
        dataToWrite = [thisFileIndex,thisTileZID,thisLayer,thisTileYID,thisTileXID];
        if any(dataToWrite<0)
            error('Generate tile index is attempting to write negative numbers. This will not work!')
        end
        fwrite(fid,[thisFileIndex,thisTileZID,thisLayer,thisTileYID,thisTileXID],'uint32');

        %The next three columns indicate for each channel in turn whether a file exists. 
        %TODO: write this as a single number and turn into binary to see which channels are present
        raw_name = sprintf('%s%d',tifPrefix,thisFileIndex);
        for chan=1:3
            thisFname=sprintf('%s_%02d.tif',fullfile(userConfig.subdir.rawDataDir,dirName,raw_name),chan);
            if exist(thisFname,'file') %This line takes most of the time
                fwrite(fid,1,'uint32');
            else
                fwrite(fid,0,'uint32');
            end
        end

        %TODO: add logic for missing tiles (which is a habit the TissueCyte has)? Right now we identify these post-hoc 

    end %for ii
end %for thisLayer 

fclose(fid);

indexPresent=1; %index has now been built