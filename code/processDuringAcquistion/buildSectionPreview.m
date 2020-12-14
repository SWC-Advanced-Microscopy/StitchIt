function varargout=buildSectionPreview(sectionToPlot,channel)
% Builds a preview image of the last completed section and send to WWW
%
% function lastDir=buildSectionPreview(sectionToPlot,channel)
%
% Purpose
% This function builds a low-res preview image of the first depth, a montage
% of all depths, and a historgram (currently not used) of the first depth.
% This is optionally sent to a webserver. If there is more than one channel,
% the main preview image is RGB. The montage image is one channel only: the 
% channel selected by the user as the second input argument. If missing, the
% channel is chosen automatically as the first available. 
%
% INPUTS
% sectionToPlot - If empty plot the last completed section. sectionToPlot can also
%                 be a directory index to plot
% channel - the channel to plot in montage image. By default (or if empty) the 
%           first available channel.
%
%
% NOTES
% Builds last completed directory as judged by the last trigger file
% the clipping level is set via the INI file.
%
% Also see:
% syncAndCrunch


userConfig = readStitchItINI;
if nargin<1 || isempty(sectionToPlot)
    sectionToPlot = lastCompletedSection; 
else
    rawDataDir = userConfig.subdir.rawDataDir;
    baseName = sprintf('%s%s%s', rawDataDir, filesep, directoryBaseName);
    sectionToPlot = sprintf('%s%04d',baseName,sectionToPlot);
end

chans=channelsAvailableForStitching;

if nargin<2 || isempty(channel)
    if isempty(chans)
        fprintf('%s finds no channels available for plotting\n',mfilename)
        return
    end
    channel=chans(1);
end


verbose=1; %Used to diagnose a MATLAB segfault that occurs at some point during image production


% Don't proceed if there a a lock file in the web-subirectory
if ~exist(userConfig.subdir.WEBdir,'dir')
    mkdir(userConfig.subdir.WEBdir)
end

lockfile=fullfile(userConfig.subdir.WEBdir,'LOCK');


if exist(lockfile,'file')
    fprintf('%s found lockfile. aborting\n',mfilename)
    varargout={};
    return
else
    fclose(fopen(lockfile,'w')); %make the lock file
end

tidyUp = onCleanup(@() thisCleanup(lockfile));



[~,thisSectionDir]=fileparts(sectionToPlot);

%The section index
tok=regexp(sectionToPlot,'.*-(\d+)','tokens'); 
ind=str2num(tok{1}{1});


rescaleThresh=userConfig.syncAndCrunch.rescaleThresh;

if rescaleThresh<25
  fprintf('Thresholding at %0.2f times the mean of the area with brain\n',rescaleThresh)
else
  fprintf('Thresholding at a pixel value of %d\n',rescaleThresh)
end


%Decide how much to resize based on tile size
params=readMetaData2Stitchit;
rSize=320/params.tile.nRows; 
if rSize>1
    rSize=1;
end
pixSize = params.voxelSize.X/rSize;
% Here we build the main image that is sent to the web. The montage of all depths
% is created later in the function
opticalSection=1;

if length(chans)==1
    fprintf('\nBuilding main image with %s: section %d, opticalSection %d, channel %d\n',mfilename,ind,opticalSection,channel)
    im=peekSection([ind,opticalSection],channel,rSize);
elseif length(chans)>1
    % Attempt to make an RGB image to send to the web
    fprintf('\nBuilding main image with %s: section %d, opticalSection %d, all channels\n',mfilename,ind,opticalSection)
    im=peekSection([ind,opticalSection],'rgb',rSize);
end

if isempty(im)
    fprintf('%s: Failed to load data. Quitting\n ',mfilename);
    return
end



%rescale and save
F=figure('visible','off');


if verbose
    fprintf('Creating main image\n')
end

[im,threshLevel]=rescaleImage(im,rescaleThresh,pixSize);

lastSection='LastCompleteSection.jpg';
imwrite(im,[userConfig.subdir.WEBdir,filesep,lastSection],'bitdepth',8)
close(F);


%Now loop through all depths and make a montage
F=figure('visible','off');
fprintf('Building montage images')

%Decide how much to resize montage based on tile size
rSize=120/params.tile.nRows; 
if rSize>1
    rSize=1;
end
pixSize = params.voxelSize.X/rSize;
if params.mosaic.numOpticalPlanes>1
    [mos,mosThresh]=rescaleImage(peekSection([ind,1],channel,rSize),rescaleThresh,pixSize);
    mos=repmat(mos,[1,1,params.mosaic.numOpticalPlanes]);

    for ii=2:params.mosaic.numOpticalPlanes
        fprintf('.')
        mos(:,:,ii)=rescaleImage(peekSection([ind,ii],channel,rSize),mosThresh,pixSize);
    end

    monFname=[userConfig.subdir.WEBdir,filesep,'montage.jpg'];
    mos=permute(mos,[1,2,4,3]);
    H=montage_noimshow(mos);
    mos=get(H,'CData');
    imwrite(mos,monFname,'bitdepth',8)
end
fprintf('\n')
close(F);



%Figure out the current section number for this series.
currentSecNum=getLastSecNum;
if currentSecNum>0
   % Stops the current section number being larger than the number of sections
   % This is only a problem if the acquisition was resumed.
   currentSecNum = currentSecNum - params.mosaic.sectionStartNum + 1; 
end

%The following string will be displayed on the website above the section 
currentTime = datestr(now,'YYYY/mm/dd HH:MM:SS');
sliceThicknessInMicrons =  params.mosaic.sliceThickness;


tok=regexp(sectionToPlot,'(.*)-(.*)','tokens');
sample=tok{1}{1};
details = sprintf('Sample: %s (%d/%d) &mdash; %0.1f &micro;m cuts &mdash; (%s)',...
    sample, currentSecNum, params.mosaic.numSections, sliceThicknessInMicrons, currentTime);


if exist('scanSettings.mat','file')
    load('scanSettings.mat')
    %TODO: also pull out wavelength
    laserPower = scanSettings.hBeams.powers(1);
    avFrames = scanSettings.hDisplay.displayRollingAverageFactor;
    if avFrames==1
        avFrames='none';
    else
        avFrames = [num2str(avFrames), ' frames'];
    end

    details = sprintf('%s\n<br />laser power: %d%%; averaging: %s', ...
        details, round(laserPower), avFrames);
end


if params.mosaic.numOpticalPlanes>1
    indexDetails = sprintf('%s - <a href="./montage.shtml">Chan %d MONTAGE</a>',details,channel);
    montageDetails = [details,' - <a href="./index.shtml">BACK</a>'];
    montageDetailsFile='details_montage.txt';
    system(sprintf('echo ''%s'' > %s',montageDetails,[userConfig.subdir.WEBdir,filesep,montageDetailsFile]));

else
    indexDetails = details;
end

% add end time if possible
endTime=estimateEndTime;
if ~isempty(endTime)
    indexDetails = sprintf('%s; %s\n\n', indexDetails, endTime.finishingString);
else
    indexDetails = sprintf('%s\n\n', indexDetails);
end

detailsFile='details.txt';
system(sprintf('echo ''%s'' > %s',indexDetails,[userConfig.subdir.WEBdir,filesep,detailsFile]));


%We also make a machine-readable text file with all the information on the current sample
%(Mosaic file) plus current progress
fidM = fopen(getTiledAcquisitionParamFile,'r');
contents = char(fread(fidM))';
fclose(fidM);

progressFname = 'progress.ini';
fidP=fopen([userConfig.subdir.WEBdir,filesep,progressFname], 'w');
fprintf(fidP,'%scurrentSection:%d\nlastWebUpdate:%s\nwebImThres:%d\n',...
    contents,currentSecNum,currentTime,rescaleThresh);
if ~isempty(endTime)
    fprintf(fidP,'expectedEndTime:%s\n', endTime.finishingString);
end
fclose(fidP);



if ~userConfig.syncAndCrunch.sendToWeb
    fprintf('Not sending to web\n')
    return
end

%and a smaller version for mobile
sendTo=userConfig.syncAndCrunch.server;

lastSection_small='LastCompleteSection_small.jpg';
imwrite(imresize(im,0.33),[userConfig.subdir.WEBdir,filesep,lastSection_small],'bitdepth',8)

%Send all to then web
returnVal=system(sprintf('LD_LIBRARY_PATH= scp -r -q %s%s* %s', userConfig.subdir.WEBdir, filesep, sendTo));

if returnVal==1
    fprintf('WARNING: image failed to send to %s. Do you have access rights to that server?\n', sendTo);
end



function [im,thresh]=rescaleImage(im,thresh,pixSize)
    % Re-scale the stitched image look up table so it is visible on screen and saves nicely
    if nargin<2
        thresh=1;
    end

    im = single(im);

    if thresh<25
        thresh = (std(im(:))+median(im(:))) * thresh;
    end


    if length(thresh)==1
        %Handles RGB images with a single threshold for all chans
        thresh = repmat(thresh,1,size(im,3))
    end


    if ~isempty(thresh)
        for ii=1:length(thresh)
            im(:,:,ii) = im(:,:,ii) ./ thresh(ii);
        end
        im(im>1)=1;
    end

    im = im * (2^8-1);
    im = uint8(im);


function thisCleanup(lockfile)
    delete(lockfile)
