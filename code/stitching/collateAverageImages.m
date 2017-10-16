function grandAverageStructure=collateAverageImages(theseDirs)
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
% This function handles both .bin files and the newer "bruteAverageTrimmean"
% .mat files. 
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
    if length(dir(grandAvDirName))>2
        fprintf('Deleting existing average data in directory %s\n', grandAvDirName)
        rmdir(grandAvDirName,'s')
    end
else
    mkdir(grandAvDirName)
end


% Find the section directory names
baseName=directoryBaseName(getTiledAcquisitionParamFile);
sectionDirs=dir([userConfig.subdir.rawDataDir,filesep,baseName,'*']);

% Bail out if no section directories were found
if isempty(sectionDirs)
    fprintf('ERROR: %s is unable to find raw data directories. Quitting.\n', mfilename)
    return
end

% Bail out if no StitchIt pre-processing directories exist
sectionStatsDirName=fullfile(userConfig.subdir.rawDataDir, userConfig.subdir.preProcessDir);
if ~exist(sectionStatsDirName,'dir')
    fprintf('ERROR: %s is unable to find the processed data directory %s. Quitting.\n', ...
        mfilename, sectionStatsDirName)
    return
end


% Choose a sub-set of these if the user asked for it 
% NOTE: This is error-prone (see help text of this function)
if nargin>0 & ~isempty(theseDirs)
    sectionDirs=sectionDirs(theseDirs);
end


%Figure out how many unique channels have average data calculated
channels = findUniqueChannels(sectionStatsDirName,sectionDirs);



% Go through each channel and calculate the average or median tile for each depth
%
for c=1:length(channels)

    % Make the directory that will house average data for this channel
    targetDir=fullfile(grandAvDirName, num2str(channels(c)));
    mkdir(targetDir)


    fprintf('Loading average data for channel %d ',channels(c))
    nImages = zeros(1,param.mosaic.numOpticalPlanes); %to keep track of the number of images

    donePreallocation=false;
    for sectionInd=1:length(sectionDirs) 

        % We attempt to gather average images from this processed data directory
        thisAverageDir = fullfile(sectionStatsDirName, sectionDirs(sectionInd).name,'averages',num2str(channels(c)));

        if ~isdir(thisAverageDir)
            % Skip this section if no such directory exists
            continue
        end

        % Get the average files. Look for brute-force .mat files and if this fails find .bin files
        % TODO: this is ultimately going to be a legacy step but for now we keep it (July, 2017)
        averageFiles = findAverageFilesInAverageChannelDir(thisAverageDir);
        if isempty(averageFiles)
            continue    
        end

        for depth = 1:length(averageFiles) % Loop over depths (one average file was made per depth)

            fname=fullfile(thisAverageDir,averageFiles(depth).name);
            tmp=loadAveBinFile(fname); % Will also handle .mat files This function is here for legacy purposes (July, 2017) TODO

            if ~donePreallocation
                % If the grand average structure has not yet been made (i.e. likely this is the first sections) then make a skeleton
                grandAverageStructure(depth) = preallocateGrandAverageStruct(tmp, length(sectionDirs));
                if depth==length(averageFiles)
                    donePreallocation=true;
                end
            end

            % Place data from this section average into the structure
            grandAverageStructure(depth).evenRows(:,:,sectionInd) = tmp.evenRows;
            grandAverageStructure(depth).oddRows(:,:,sectionInd) = tmp.oddRows;
            grandAverageStructure(depth).evenN(sectionInd) = tmp.evenN;
            grandAverageStructure(depth).oddN(sectionInd) = tmp.oddN;

        end

        if ~mod(sectionInd,5)
            fprintf('.')
        end
    end
    fprintf('\n')

    % Handle missing data and calculate grand average
    fprintf('Calculating final tiles')
    for depth=1:length(grandAverageStructure) % Loop over depths again

        %look for nans

        avData = grandAverageStructure(depth);

        fEven = squeeze( any(any(isnan(avData.evenRows))) );
        fOdd = squeeze( any(any(isnan(avData.oddRows))) );

        fEven = find(fEven);
        fOdd = find(fOdd);
        f = unique([fEven;fOdd]); % all sections with missing data in any rows

        if ~isempty(f)
            fprintf('\n%d missing averages out of %d section directories for depth %d\n', length(f), length(sectionDirs), avData.layer)
            %Remove these data
            avData.evenRows(:,:,f)=[];
            avData.oddRows(:,:,f)=[];
            avData.evenN(f)=[];
            avData.oddN(f)=[];
        end

        if isempty(avData.evenRows)
            fprintf('No average images in depth %d. Skipping\n', avData.layer)
            continue
        end
        % Average the mean images
        avData.evenRows=trimmean(avData.evenRows,10,'round',3);
        avData.oddRows=trimmean(avData.oddRows,10,'round',3);
        avData.evenN=sum(avData.evenN);
        avData.oddN=sum(avData.oddN);

        %And the grand average
        avData.pooledRows = (avData.evenRows + avData.oddRows)/2;
        avData.poolN = avData.evenN + avData.oddN;

        fname = sprintf('%02d_%s.mat',avData.layer, avData.correctionType);
        fullPath = fullfile(targetDir, fname);
        save(fullPath,'avData')
        fprintf('.')
    end
    fprintf('\n')

end



% ------------------------------------------------------------------------------------------------------------
% Internal functions
function templateStructure = preallocateGrandAverageStruct(templateStructure, numSections)
    % This function preallocates an empty structure into which we can place the average tiles

    % First clear the structure by populating everything wth nans
    templateStructure.evenRows(:) = nan;
    templateStructure.oddRows(:) = nan;
    templateStructure.pooledRows = []; %Because we'll calculate this at the end
    templateStructure.evenN = nan;
    templateStructure.oddN = nan;
    templateStructure.poolN = nan;

    %Now expand these for the number of sections
    templateStructure.evenRows = repmat(templateStructure.evenRows,[1,1,numSections]);
    templateStructure.oddRows = repmat(templateStructure.oddRows,[1,1,numSections]);
    templateStructure.evenN = repmat(templateStructure.evenN,1,numSections);
    templateStructure.oddN = repmat(templateStructure.oddN,1,numSections);



function channels = findUniqueChannels(sectionStatsDirName,sectionDirs)
    % Determines how many unique channels have average data calculated
    channels=[];

    for ii=1:length(sectionDirs) 
        thisAverageDir = fullfile(sectionStatsDirName,sectionDirs(ii).name,'averages');

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

    channels=unique(channels); % These are the unique channels


function averageFiles = findAverageFilesInAverageChannelDir(thisAverageDir)
    % Get the average files. Look for brute-force .mat files and if this fails find .bin files
    % TODO: this is ultimately going to be a legacy step but for now we
    averageFiles = dir(fullfile(thisAverageDir,'*_bruteAverageTrimmean.mat'));
    if ~isempty(averageFiles)
        return
    end

    averageFiles = dir(fullfile(thisAverageDir,'*.bin'));
    if isempty(averageFiles)
        averageFiles=[];
        fprintf('NO AVERAGE FILES FOUND\n')
    end


