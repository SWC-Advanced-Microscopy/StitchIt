function varargout=buildSectionPreview(sectionToPlot,channel)
% Builds a preview image of the last completed section and send to WWW
%
% function lastDir=buildSectionPreview(sectionToPlot,channel)
%
% INPUTS
% sectionToPlot - If empty plot the last completed section as per the trigger file
%                 sectionToPlot can also be a directory index to plot
% channel - the channel to plot. By default the first available channel. 
%
%
% NOTES
% builds last completed directory as judged by the last trigger file
% the clipping level is set via the INI file.
%
% Also see:
% syncAndCrunch

if nargin<1 || isempty(sectionToPlot)
    sectionToPlot = lastCompletedSection; 
else
    userConfig = readStitchItINI;
    rawDataDir = userConfig.subdir.rawDataDir;
    baseName = sprintf('%s%s%s', rawDataDir, filesep, directoryBaseName);
    sectionToPlot = sprintf('%s%04d',baseName,sectionToPlot);
end

if nargin<2
    chans=channelsAvailableForStitching;
    if isempty(chans)
        fprintf('%s finds no channels available for plotting\n',mfilename)
        return
    end
    channel=chans(1);
end


verbose=1; %Used to diagnose a MATLAB segfault that occurs at some point during image production

[~,thisSectionDir]=fileparts(sectionToPlot);
generateTileIndex(thisSectionDir,[],0);

%The section index
tok=regexp(sectionToPlot,'.*-(\d+)','tokens'); 
ind=str2num(tok{1}{1});


userConfig=readStitchItINI;
rescaleThresh=userConfig.syncAndCrunch.rescaleThresh;

if rescaleThresh>1
  fprintf('Thresholding at a pixel value of %d\n',rescaleThresh)
elseif rescaleThresh<1
  fprintf('Thresholding at %d percent\n',rescaleThresh*100)
end


%Decide how much to resize based on tile size
params=readMetaData2Stitchit;
rSize=320/params.tile.nRows; 
if rSize>1
    rSize=1;
end

opticalSection=1;
fprintf('\nBuilding main image with %s: section %d, opticalSection %d, channel %d\n',mfilename,ind,opticalSection,channel)
im=peekSection([ind,opticalSection],channel,rSize);
if isempty(im)
    fprintf('%s: Failed to load data. Quitting\n ',mfilename);
    return
end



%rescale and save
F=figure('visible','off');


if ~exist(userConfig.subdir.WEBdir,'dir')
    mkdir(userConfig.subdir.WEBdir)
end

if verbose
    fprintf('Creating main image\n')
end

[im,threshLevel]=rescaleImage(im,rescaleThresh);

lastSection='LastCompleteSection.jpg';
imwrite(im,[userConfig.subdir.WEBdir,filesep,lastSection],'bitdepth',8)
close(F);

%Write histogram to disk
if verbose
    fprintf('Setting up non-visible histogram figure\n')
end
F=figure('visible','off');

if verbose
    fprintf('Running sectionHist\n')
end
sectionHist(im,threshLevel)

if verbose
    fprintf('Set paper size, invert hard copy, save\n')
end
set(F,'paperposition',[0,0,6,3],'InvertHardCopy','off')
print('-dpng','-r100',[userConfig.subdir.WEBdir,filesep,'hist.png']);
close(F);



%Now loop through all depths and make a montage
F=figure('visible','off');
fprintf('Building montage images')

%Decide how much to resize montage based on tile size
params=readMetaData2Stitchit;
rSize=120/params.tile.nRows; 
if rSize>1
    rSize=1;
end

if params.mosaic.numOpticalPlanes>1
    mos=rescaleImage(peekSection([ind,1],channel,rSize),rescaleThresh);
    mos=repmat(mos,[1,1,params.mosaic.numOpticalPlanes]);
    for ii=1:params.mosaic.numOpticalPlanes
        fprintf('.')
        mos(:,:,ii)=rescaleImage(peekSection([ind,ii],channel,rSize),rescaleThresh);
    end
    monFname=[userConfig.subdir.WEBdir,filesep,'montage.jpg'];
    mos=permute(mos,[1,2,4,3]);
    H=montage_noimshow(mos);
    mos=get(H,'CData');
    imwrite(mos,monFname,'bitdepth',8)
end
fprintf('\n')
close(F);



%Figure out the current section number for this series. However, we can't just use
%the number from the directory file name since this will be wrong if we asked for the 
%numbering to start >1. Thus we have to calculate the current section number. Doing it 
%this way is more robust than counting the number of directories minus 1 since it's
%conceivable someone could delete directories during the acquisition routine. This way
%it only matters what the first directory is.
tok=regexp(sectionToPlot,'(.*)-(.*)','tokens');
sample=tok{1}{1};
thisSecNum = str2num(tok{1}{2});


d=dir([userConfig.subdir.rawDataDir,filesep,directoryBaseName,'*']);
if ~isempty(d)
   tok=regexp(d(1).name,'(.*)-(.*)','tokens');
   firstSecNum = str2num(tok{1}{2});
   currentSecNum = thisSecNum - firstSecNum + 1;
else
  currentSecNum = 0;
  fprintf('Can not find section number.\n')
end


%The following string will be displayed on the website above the section 
currentTime = datestr(now,'YYYY/mm/dd HH:MM:SS');
sliceThicknessInMicrons =  params.mosaic.sliceThickness;


details = sprintf('Sample: %s (%d/%d) &mdash; %d &micro;m cuts &mdash; (%s)',...
    sample, currentSecNum, params.mosaic.numSections, sliceThicknessInMicrons, currentTime);

endTime=estimateEndTime;

if params.mosaic.numOpticalPlanes>1
    indexDetails = [details,' - <a href="./montage.shtml">MONTAGE</a>'];
    montageDetails = [details,' - <a href="./index.shtml">BACK</a>'];
    montageDetailsFile='details_montage.txt';
    system(sprintf('echo ''%s'' > %s',montageDetails,[userConfig.subdir.WEBdir,filesep,montageDetailsFile]));

else
    indexDetails = details;
end
indexDetails = sprintf('%s\n<br />\nChannel: %d ; %s\n\n',...
    indexDetails, channel,endTime.finishingString);

detailsFile='details.txt';
system(sprintf('echo ''%s'' > %s',indexDetails,[userConfig.subdir.WEBdir,filesep,detailsFile]));


%We also make a machine-readable text file with all the information on the current sample
%(Mosaic file) plus current progress
fidM = fopen(getTiledAcquisitionParamFile,'r');
contents = char(fread(fidM))';
fclose(fidM);

progressFname = 'progress.ini';
fidP=fopen([userConfig.subdir.WEBdir,filesep,progressFname], 'w');
fprintf(fidP,'%scurrentSection:%d\nexpectedEndTime:%s\nlastWebUpdate:%s\nwebImThres:%d\n',...
    contents,currentSecNum,endTime.finishingString,currentTime,rescaleThresh);
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



function [im,thresh]=rescaleImage(im,thresh)
    if nargin<2
        thresh=1;
    end

    if thresh<1 
        thresh=thresh*2^16;
    elseif thresh==1
        thresh=max(im(:));
    else
        %thresh is a pixel intensity value
    end

    im = single(im);
    if ~isempty(thresh)
        im = im ./ thresh;
        im(im>1)=1;
    end

    im = im * (2^8-1);
    im = uint8(im);