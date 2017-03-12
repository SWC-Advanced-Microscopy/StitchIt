function varargout = generateTileIndex(obj,sectionDir,~,verbose)
% For user documentation run "help generateTileIndex" at the command line

% No 3rd arg needed:
% BakingTray doesn't need to generate a tile index because, unlike the TissueCyte,
% all information needed to build the tiles is explicitly saved with them. Consequently,
% this function returns outputs consistent with it having done something but in fact it 
% does nothing more than confirm the tilePositions.mat file is present


%Check input args
if nargin < 2 | isempty(sectionDir)
    sectionDir=[];
end

if nargin<4
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
    indexPresent=isIndexFileInDirectory(obj,sectionDir,userConfig);
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
    indexPresent(thisDir)=isIndexFileInDirectory(obj,sectionDirectories(thisDir).name,userConfig);

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


    if mod(length(TIFFS),numExpectedTIFFsPerChannel)==0
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
function indexPresent=isIndexFileInDirectory(obj,dirName,userConfig)
% returns 1 if index file was found 0 otherwise, indicating that index file is missing

% TODO: the index file will always be present in bakingtray data, even if not all tiles are
%       present. With TV data, a missing index file indicates that not all data were acquired. 
%       So we need to decide how to proceed in this regard for other data sets. 

%Skip if the *tileStats* file has already been written
tileIndexFname = fullfile(userConfig.subdir.rawDataDir,dirName,'tileIndex');
if exist(tileIndexFname,'file');
    indexPresent = 1;
else
    indexPresent = 0;
end

