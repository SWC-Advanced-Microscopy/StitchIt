function varargout = generateTileIndex(sectionDir,~,verbose)
% Index all raw data tiles in an experiment, link original file names to position in tile array 
%
%
% A tile is defined as a single 2-D image. Each tile is located in a unique position in the
% 3-D sample. StitchIt uses an index file to associate each tile coordinate with a file. 
% The index file is called "tileIndex" and is present in each raw data directory. 
% The file is binary. It's composed of 32 bit unsigned ints. The first int defines the
% size of one record row. This function doesn't load the TIFFs. It simply indexes 
% based on file names. 
%
% function [nCompleted,indexPresent] = generateTileIndex(sectionDir,forceOverwrite,verbose)
% 
%
% INPUTS
% sectionDir - [empty or string]. If a string, it should be the name of a section directory
%               within the raw data dirctory. If so we generate the index for this directory only. 
%               Otherwise (if empty) the function loops through all section directories in the
%               raw data directory.
% forceOverwrite - zero by default. If 1 the function over-write existing the existing
%                  tileIndex file
% verbose - few messages if 0. 1 by default, for more messages.
%
%
% OUTPUTS
% nCompleted - Optionally return the number of directories containing an index file 
% indexPresent - vector indicating which sections have a tile index file and which do not.
%
%
% EXAMPLES
% 1) Loop through all directories and add tileIndex files only where they're missing:
% generateTileIndex
% or
% generateTileIndex([],0)
%
% 2) Regenerate all tile index files in all directories
% generateTileIndex([],1)
%
% 3) Regenerate tile index file for section 33 only (rawData directory appended automatically)
% generateTileIndex('K102-0001',1) 
%
% 4) how many directories contain an index file
% n = generateTileIndex;
%
%
%
% Rob Campbell - Basel 2014
%
%
% See also: readTileIndex


% No 2nd arg needed:
% BakingTray doesn't need to generate a tile index because, unlike the TissueCyte,
% all information needed to build the tiles is explicitly saved with them. Consequently,
% this function returns outputs consistent with it having done something but in fact it 
% does nothing more than confirm the tilePositions.mat file is present


%Check input args
if nargin < 1 | isempty(sectionDir)
    sectionDir=[];
end

if nargin<3
    verbose=1;
end

userConfig=readStitchItINI;

if ~exist(userConfig.subdir.rawDataDir,'dir')
    error('Can not find raw data directory: .%s%s',filesep,userConfig.subdir.rawDataDir)
end


paramFile=getTiledAcquisitionParamFile;
[data,successfulRead]=readMetaData2Stitchit(paramFile);
if ~successfulRead
    fprintf('failed to read all tiles from %s\n',paramFile)
    if nargout>0
        varargout{1}=0;
    end

    return
end


if verbose
    %Report experiment details to screen
    fprintf(['\nFound experiment with the following parameters:\n',...
         ' Tile size: %d^2\n',...
         ' Expected final number of physical sections: %d\n',...
         ' Section thickness: %d\n',...
         ' Optical sections: %d\n',...
         ' Tiles: %d by %d \n'],...
         data.tile.nRows, data.mosaic.numSections, data.mosaic.sliceThickness,...
         data.mosaic.numOpticalPlanes, data.numTiles.X, data.numTiles.Y)
end


%Find the raw directories we will descend into. 
if isempty(sectionDir)
    baseName=directoryBaseName(paramFile);
    directorySearchPath=fullfile(userConfig.subdir.rawDataDir,[baseName,'*']);
    sectionDirectories=dir(directorySearchPath);
else
    indexPresent=isIndexFileInDirectory(sectionDir,userConfig);
    if nargout>0
        varargout{1}=sum(indexPresent);
    end
    if nargout>1
        varargout{2}=indexPresent;
    end

    return
end


if isempty(sectionDirectories)
    error('Can not find any raw data directories in %s',directorySearchPath)
else
    if verbose
        fprintf('\nFound %d raw data directories\n', length(sectionDirectories))
    end
end


% Search for tile index files 
indexPresent=ones(1,length(sectionDirectories));

%Loop through all section directories
for thisDir = 1:length(sectionDirectories)
    indexPresent(thisDir)=isIndexFileInDirectory(sectionDirectories(thisDir).name,userConfig);

    if indexPresent(thisDir)
        continue
    end

    %if there is no completed file then we don't build the index
    if ~exist(fullfile(userConfig.subdir.rawDataDir,sectionDirectories(thisDir).name,'COMPLETED'),'file')
        continue
    end
    
    %make the index only if all files are present
    numExpectedTIFFsPerChannel = data.numTiles.X * data.numTiles.Y;
    TIFFS = dir(fullfile(userConfig.subdir.rawDataDir, sectionDirectories(thisDir).name,'*.tif'));


    % If this isn't auto-ROI, we check whether all tiles have been acquired
    if ~strcmp(data.mosaic.scanmode, 'tiled: auto-ROI') && mod(length(TIFFS),numExpectedTIFFsPerChannel)==0
        allTilesAcquired=true;
    elseif strcmp(data.mosaic.scanmode, 'tiled: auto-ROI')
        % We simply assume it ran to completion in this mode as there is no hard rule regarding how many tiles should be there.
        % This could be modified in the future, but for now this will work.
        allTilesAcquired=true;
    else
        allTilesAcquired=false;
    end

    if allTilesAcquired
        fname=fullfile(userConfig.subdir.rawDataDir, sectionDirectories(thisDir).name,'tileIndex');
        fid = fopen(fname,'w+');
        fprintf('Writing empty tileindex to %s\n',fname);
        fprintf(fid,'tileindex\n');
        fclose(fid);
    else
        fprintf('Raw data directory %s claims it is completed but the number of TIFFs is not what was expected. SKIPPING.\n ',...
         sectionDirectories(thisDir).name)
    end

end

%Handle output arguments
if nargout>0
    varargout{1}=sum(indexPresent);
end
if nargout>1
    varargout{2}=indexPresent;
end



% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
function indexPresent=isIndexFileInDirectory(dirName,userConfig)
% returns 1 if index file was found 0 otherwise, indicating that index file is missing

% TODO: the index file will always be present in bakingtray data, even if not all tiles are
%       present. With TV data, a missing index file indicates that not all data were acquired. 
%       So we need to decide how to proceed in this regard for other data sets. 

%Skip if the *tileIndex* file has already been written
tileIndexFname = fullfile(userConfig.subdir.rawDataDir,dirName,'tileIndex');
if exist(tileIndexFname,'file');
    indexPresent = 1;
else
    indexPresent = 0;
end

