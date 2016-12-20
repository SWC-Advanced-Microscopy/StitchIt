function collateAverageImages(theseDirs)
% Loop through data directories and use saved average files to create grand average images
%
% function collateAverageImages(theseDirs)
%
% PURPOSE
% Create the grand average images that can be used for background subtraction. 
% Over-writes any existing grand average images. Writes all available channels 
% that have averaged data. 
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

mosaicFile=getTiledAcquisitionParamFile;
param=readMetaData2Stitchit(mosaicFile);

userConfig=readStitchItINI;

grandAvDirName = [userConfig.subdir.rawDataDir,filesep,userConfig.subdir.averageDir,filesep];

if exist(grandAvDirName,'dir')
    fprintf('Deleting existing average directory tree\n')
    rmdir(grandAvDirName,'s')
end

mkdir(grandAvDirName)


%Find directory names
baseName=directoryBaseName(getTiledAcquisitionParamFile);
sectionDirs=dir([userConfig.subdir.rawDataDir,filesep,baseName,'*']);
if isempty(sectionDirs)
    fprintf('Unable to find raw data directories\n')
end


if nargin>0 & ~isempty(theseDirs)
    sectionDirs=sectionDirs(theseDirs);
end



%Figure out how many channels there 
rawDataDir = [userConfig.subdir.rawDataDir,filesep];
channels=[];

for ii=1:length(sectionDirs) 
    thisAverageDir = [rawDataDir,sectionDirs(ii).name,filesep,'averages',filesep];

    if ~isdir(thisAverageDir), continue, end

    channelDirs = dir(thisAverageDir);
    if isempty(channelDirs), continue, end
    channelDirs(1:2)=[]; %these are the current and previous directory links

    %Shitty algorithm, but it works. 
    channels = [channels,cellfun(@str2num,{channelDirs.name})]; 
end

channels=unique(channels);



%Go through each channel and calculate the average or median tile for each depth
for c=1:length(channels)
    targetDir=sprintf('%s%d%s',grandAvDirName,channels(c),filesep);
    mkdir(targetDir)


    if c==1
        fprintf('Pre-allocating arrays for channel %d',channels(c))
        for ii = 1:param.mosaic.numOpticalPlanes
            avData{ii} = nan([param.tile.nRows, param.tile.nColumns,2,length(sectionDirs)]); %i.e. pixel rows x pixel cols * num tiles
            fprintf('.')
        end
     else %All subsequent times we just wipe the arrays
        fprintf('Clearing arrays for channel %d',channels(c))
        for ii = 1:param.mosaic.numOpticalPlanes
            avData{ii}(:,:,:,:) = nan;
            fprintf('.')
        end
     end

    fprintf('\n')

    fprintf('Loading data for channel %d ',channels(c))
    nImages = zeros(1,param.mosaic.numOpticalPlanes); %to keep track of the number of images
    for ii=1:length(sectionDirs) 

         thisAverageDir = fullfile(rawDataDir,sectionDirs(ii).name,'averages',num2str(channels(c)));
         if ~isdir(thisAverageDir), continue, end

         averageFiles = dir(fullfile(thisAverageDir,'*.bin'));

         for avFile = 1:length(averageFiles) 
            %Get the depth associated with this depth
            fname=averageFiles(avFile).name;
            tok=regexp(fname,'.*?(\d+)\.bin','tokens');
            depth=str2num(tok{1}{1});

            fname=fullfile(thisAverageDir,averageFiles(avFile).name);
            [tmp,n]=loadAveBinFile(fname);
            avData{depth}(:,:,:,ii) = tmp;
            nImages(avFile) = nImages(avFile)+n;
         end

         if ~mod(ii,5)
            fprintf('.')
         end
     end
     fprintf('\n')

     %handle missing data and calculate average
     fprintf('Calculating final tiles')
     for ii=1:param.mosaic.numOpticalPlanes

                tmp=squeeze(any(any(isnan(avData{ii}))));
                tmp=tmp(1,:); %search of nans here. yuk
        f=find(tmp ); 

        if ~isempty(f)
            fprintf('\n%d missing averages out of %d in depth %d\n',length(f),size(avData{ii},4),ii)
            avData{ii}(:,:,:,f) = [];
        end
        
        if isempty(avData{ii})
            fprintf('No average images. Skipping\n')
            continue
        end

        % Average the mean images
        %mu = mean(avData{ii},4);
        %mu=median(avData{ii},4);
        mu=trimmean(avData{ii},10,'round',4);

        writeAveBinFile(sprintf('%s%02d.bin',targetDir,ii), mu(:,:,1), mu(:,:,2),nImages(ii));
        fprintf('.')
     end
     fprintf('\n')

end

