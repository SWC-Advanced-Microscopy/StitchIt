function varargout=identifyMissingTilesInDir(directoryName,reportOnly,verbose,maxMissingThreshold,writeBlacktile)
% Identify missing tiles and create empty tiles to fill these slots
%	
% function blankTiles=identifyMissingTilesInDir(directoryName,reportOnly,verbose,maxMissingThreshold))
%
%
% PURPOSE
% The TissueCyte has a habit of randomly failing to acquire tiles. This function
% searches directoryName for missing tiles and optionally creates new, 
% blank, tiles to replace any missing ones. It reports missing tiles
% to the screen and optionally returns them as a cell array.
%
%
% INPUTS
% directoryName - the relative or absolute path to either:
%                 a) the section directory containing the raw TIFF files
%                 b) the raw data directory containing the section dirs. 
%                    In this latter case, the function loops through all 
%                    section directories. 
% reportOnly - don't attempt to fix, just report what is missing [1 by default]
%
%
% Output
% blankTiles - [cell array, optional] a list of file names to the blank 
%              tiles that were added.
%
%
% Examples
% identifyMissingTilesInDir('rawData/XY102-0052') %report missing tiles from section 52 only
% identifyMissingTilesInDir('rawData') %report missing tiles from all sections
% identifyMissingTilesInDir('rawData',0) %fix missing tiles in all sections
% 
% 
% Rob Campbell - Basel 2015


if nargin<2 || isempty(reportOnly)
	reportOnly=1;
end

%Hidden arguments
if nargin<3 || isempty(verbose)
	verbose=1; %we set this to zero in batch mode to keep things neater
end

if nargin<4
	maxMissingThreshold=[]; %If non-zero, we don't fix tiles greater than this number.
							%We set this for the last section only when in batch mode.
end

if nargin<5
	writeBlacktile=1; %If non-zero, we don't fix tiles greater than this number.
							%We set this for the last section only when in batch mode.
end
% ----------------------


%Figure out if we are to crunch one directory or all of them
param = readMetaData2Stitchit;

DIRS=dir(fullfile(directoryName,[param.sample.ID,'-*']));
TIFF=dir(fullfile(directoryName,'*.tif'));

%The we will go through all section directories
if isempty(TIFF) && ~isempty(DIRS)
    fprintf('Searching all section directories\n')
	fnames = {};
	maxMissingThreshold=[];
	for ii=1:length(DIRS)
		if ~DIRS(ii).isdir
			fprintf('%s not a directory. skipping it\n', DIRS(ii).name)
			continue
		end
		if ii==length(DIRS)
			maxMissingThreshold=40;
        end
        if verbose
            fprintf('Searching %s\n',DIRS(ii).name);
        end
		thisDir=fullfile(directoryName,DIRS(ii).name);
		theseFnames = identifyMissingTilesInDir(thisDir,reportOnly,0,maxMissingThreshold,writeBlacktile);
		fnames = [fnames; theseFnames(:)];
	end
	if nargout>0
		varargout{1}=fnames;
	end

	return

end %if isempty(TIFF) & ~isempty(DIRS)



%Expected number of images
nImagesPerLayer = param.numTiles.X * param.numTiles.Y; %The number of images in one optical section 
nImagesPerSection = param.mosaic.numOpticalPlanes * nImagesPerLayer;


%Let's use the file ending to see if we have three channels or two channels. 
firstN=10;
if length(TIFF)<firstN %Don't proceed if directory contains very few files
	fprintf('Fewer than %d files in directory %s. SKIPPING\n',firstN,directoryName);
	if nargout>0
		varargout{1} = {};
	end
	return
end

firstBunch = {TIFF(1:firstN).name};
chans = unique(cell2mat(cellfun(@(x) str2num(x(end-5:end-4)),...
	firstBunch,'UniformOutput',false)));

expectedImages = nImagesPerSection*length(chans);

if expectedImages == length(TIFF)
	if verbose
		fprintf('All images appear to be present\n')
	end
	if nargout>0
		varargout{1}={};
	end
	return
elseif expectedImages < length(TIFF)
	fprintf('\n%s: We have *MORE* images than expected: %d rather than %d. SKIPPING\n', directoryName, length(TIFF), expectedImages)
	if nargout>0
		varargout{1}={};
	end
	return
else
	fprintf('\n%s: Expected %d images but found %d\n',directoryName,expectedImages,length(TIFF))
end


%Get section ID of current directory
M=dir(fullfile(directoryName,'Mosaic*.txt'));
if isempty(M)
	fprintf('Can not find section mosaic file. SKIPPING\n')
	if nargout>0
		varargout{1}={};
	end
	return
end
if length(M)>1
	fprintf('Found more than one mosaic file in section directory. SKIPPING\n')
	if nargout>0
		varargout{1}={};
	end
	return
end

sectionParams = readMetaData2Stitchit(fullfile(directoryName,M.name));

%File indexes in this directory
fileIndex = sectionParams.mosaic.sectionStartNum + (0:(nImagesPerSection-1));


%So see which ones are missing 
tiffPrefix = TIFF(1).name(1:14);
missingFiles={};
numMissing = expectedImages-length(TIFF);
for c=1:length(chans)
	for fInd=1:length(fileIndex)

		fname = sprintf('%s%d_%02d.tif', tiffPrefix, fileIndex(fInd), c);
		if ~exist(fullfile(directoryName,fname),'file')
			missingFiles = [missingFiles; fullfile(directoryName,fname)];
		end
		if isempty(maxMissingThreshold)
			if length(missingFiles) == numMissing
				fprintf('Found missing tiles in %s: \n',directoryName);
				break
			end
		else
			if numMissing>maxMissingThreshold
				fprintf('Found %d missing tiles. That is a lot. SKIPPING.\n',numMissing)
				if nargout>0
					varargout{1}={};
				end
				return
			end
		end %if isempty(maxMissingThreshold)

	end
end



fprintf('%s\n',missingFiles{:}) %print missing tiles to screen



%If the user asked for it (off by default) replace these tiles with black
if reportOnly
	if nargout>0
		varargout{1}=missingFiles;
	end
	return
end


blackImage = zeros([sectionParams.tile.nRows,sectionParams.tile.nColumns],'uint16');

blankTiles={};
for ii=1:length(missingFiles)
	fname = missingFiles{ii};
	if exist(fname,'file')
		fprintf('WARNING: %s indeed exists. Not over-writing\n',fname)
		continue
	end
	
	if writeBlacktile
        imwrite(blackImage,fname,'Compression','none')
        if exist(fname,'file')
			fprintf('Wrote blank tile to %s\n',fname)
			blankTiles{length(blankTiles)+1}=fname;
		else
			fprintf('  * Tried to write blank tile to %s but failed *\n',fname)
		end
    else
        SplitedName1 = strsplit (fname,'-');
        SplitedName2 = SplitedName1{4};
        SplitedName = strsplit (SplitedName2,'_');
        nUpperLayer = str2double(SplitedName(:,1))+nImagesPerLayer;
        nLowerLayer = str2double(SplitedName(:,1))-nImagesPerLayer;
        UpperLayerImage = strcat (SplitedName1(:,1),'-',SplitedName1(:,2),'-', SplitedName1(:,3),'-',int2str(nUpperLayer),'_', SplitedName(:,2));
        LowerLayerImage = strcat (SplitedName1(:,1),'-',SplitedName1(:,2),'-', SplitedName1(:,3),'-',int2str(nLowerLayer),'_', SplitedName(:,2));

        if exist (UpperLayerImage{1}, 'file')
               copyfile (UpperLayerImage{1}, fname);
        elseif exist (LowerLayerImage{1}, 'file')
               copyfile (LowerLayerImage{1}, fname);
        else 
               display 'You have no image to fill the hole. ';
               imwrite(blackImage,fname,'Compression','none')
               if exist(fname,'file')
                   fprintf('Wrote blank tile to %s\n',fname)
                   blankTiles{length(blankTiles)+1}=fname;
               else
                   fprintf('  * Tried to write blank tile to %s but failed *\n',fname)
               end
        end
    end
	


end


if nargout>0
	varargout{1}=blankTiles;
end
