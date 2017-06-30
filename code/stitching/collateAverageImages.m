function collateAverageImages(theseDirs)
% Loop through data directories and use saved average files to create grand average images
%
% function collateAverageImages(theseDirs)
%
% PURPOSE
% Create the grand average images that can be used for background subtraction. 
% Over-writes any existing grand average images. Writes all available channels 
% that have averaged tiles calculated. These average tiles are located in a 
% directory called "averages" along with the raw section tiles.
%
%
% INPUTS
% theseDirs - an optional vector of indexes telling the function which directories
%             to use. NOTE if the directories on disk go from sections 10 to 50 and
%             theseDirs is 1:10 then we will collate sections 10 to 19. This is 
%             useful when the early and/or late sections contain mostly empty tiles.
%             if theseDirs is empty, all directories are processed.
%
% OUTPUTS
% None - data are saved to disk
%
%
% Rob Campbell - Basel 2014


% Read meta-data 
mosaicFile=getTiledAcquisitionParamFile;
param=readMetaData2Stitchit(mosaicFile);
userConfig=readStitchItINI;

% Determine the name of the directory to which we will write data
grandAvDirName = fullfile(userConfig.subdir.rawDataDir, userConfig.subdir.averageDir);

if exist(grandAvDirName,'dir')
    fprintf('Deleting existing average directory tree\n')
    rmdir(grandAvDirName,'s')
else
    mkdir(grandAvDirName)
end

% Find directory names
baseName=directoryBaseName(getTiledAcquisitionParamFile);
sectionDirs=dir([userConfig.subdir.rawDataDir,filesep,baseName,'*']);
if isempty(sectionDirs)
    fprintf('Unable to find raw data directories\n')
end


if nargin>0 & ~isempty(theseDirs)
    sectionDirs=sectionDirs(theseDirs);
end



%Figure out how many channels there 
rawDataDir = userConfig.subdir.rawDataDir;
channels=[];

for ii=1:length(sectionDirs) 
    thisAverageDir = fullfile(rawDataDir,sectionDirs(ii).name,'averages');

    if ~isdir(thisAverageDir)
        continue
    end

    channelDirs = dir(thisAverageDir);

    if isempty(channelDirs)
        continue
    end

    channelDirs(1:2)=[]; %these are the current and previous directory links

    channels = [channels, cellfun(@str2num,{channelDirs.name})]; 
end

channels=unique(channels);


%Go through each channel and calculate the average or median tile for each depth
for c=1:length(channels)
    targetDir=fullfile(grandAvDirName, num2str(channels(c)));
    mkdir(targetDir)


    fprintf('Loading data for channel %d ',channels(c))
    nImages = zeros(1,param.mosaic.numOpticalPlanes); %to keep track of the number of images
    for sectionInd=1:length(sectionDirs) 

        % We attempt to gather average images  from this directory
        thisAverageDir = fullfile(rawDataDir,sectionDirs(sectionInd).name,'averages',num2str(channels(c)));

        if ~isdir(thisAverageDir)
            % Skip this section if no such directory exists
            continue
        end

        averageFiles = dir(fullfile(thisAverageDir,'*.bin'));

        for avFile = 1:length(averageFiles) 
            %Get the depth associated with this depth
            fname=averageFiles(avFile).name;
            tok=regexp(fname,'.*?(\d+)\.bin','tokens');
            depth=str2num(tok{1}{1});

            fname=fullfile(thisAverageDir,averageFiles(avFile).name);
            [tmp,n]=loadAveBinFile(fname);

            %Pre-allocate based on current array
            if sectionInd==1 && avFile==1
                if c==1
                    avData = preallocateAveArray(size(tmp), param.mosaic.numOpticalPlanes, length(sectionDirs));
                else
                    % For all subsequent channels we can just wipe the existing arrays
                    for ii = 1:param.mosaic.numOpticalPlanes
                        avData{ii}(:,:,:,:) = nan;
                    end
                end
            end

            % Place data from this average into the stack 
            avData{depth}(:,:,:,sectionInd) = tmp;
            nImages(avFile) = nImages(avFile)+n;
        end

        if ~mod(sectionInd,5)
            fprintf('.')
         end
    end
    fprintf('\n')



     % Handle missing data and calculate grand average
     fprintf('Calculating final tiles')
     for depth=1:length(avData) % Loop over depths

        dataFromThisDepth = avData{depth};

        tmp=squeeze(any(any(isnan(avData{depth}))));
        tmp=tmp(1,:); %search of nans here. yuk
        f=find(tmp ); 


        if ~isempty(f)
            fprintf('\n%d missing averages out of %d in depth %d\n', length(f), size(avData{depth},4), ii)
            avData{depth}(:,:,:,f) = [];
        end

        if isempty(avData{depth})
            fprintf('No average images. Skipping\n')
            continue
        end

        % Average the mean images
        %mu = mean(avData{ii},4);
        %mu = median(avData{ii},4);
        mu=trimmean(avData{depth},10,'round',4);

        fname = fullfile(targetDir, sprintf('%02d.bin', depth));
        writeAveBinFile(fname, mu(:,:,1), mu(:,:,2), nImages(depth));
        fprintf('.')
     end
     fprintf('\n')

end


% internal functions
function emptyArray = preallocateAveArray(avTileSize, numOpticalPlanes, numSections)
    % This function is used to create an empty array into which we can place the average tiles
    for ii = 1:numOpticalPlanes
        emptyArray{ii} = nan([avTileSize, numSections]); %i.e. pixel rows x pixel cols * num tiles
    end
