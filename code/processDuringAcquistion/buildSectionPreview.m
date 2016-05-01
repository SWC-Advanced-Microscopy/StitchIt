function varargout=buildSectionPreview(sectionToPlot,channel)
% runs every waitTime minutes and searches the current directory for new data
%
% function lastDir=buildSectionPreview(sectionToPlot,channel)
%
% INPUTS
% sectionToPlot - If empty plot the last completed section as per the trigger file
%                 sectionToPlot can also be a directory index to plot
% channel - the channel to plot [2 by default]
%
%
% NOTES
% builds last completed directory as judged by the last trigger file
% the clipping level is set via the INI file.
%
% Also see:
% syncAndCrunch

if nargin<1 || isempty(sectionToPlot)
	[~,sectionToPlot] = lastCompletedSection; 
else
	userConfig = readStitchItINI;
	rawDataDir = userConfig.subdir.rawDataDir;
	baseName = sprintf('%s%s%s', rawDataDir, filesep, directoryBaseName);
	sectionToPlot = sprintf('%s%04d',baseName,sectionToPlot);
end

if nargin<2
	channel=2;
end



generateTileIndex(sectionToPlot,[],0)

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




rSize=0.4; %how much we will resize
opticalSection=1;
fprintf('\nBuilding main image with %s: section %d, opticalSection %d, channel %d\n',mfilename,ind,opticalSection,channel)
im=peekSection([ind,opticalSection],channel,rSize); %TODO: send all opticalSections and make buttons to switch between them
if isempty(im)
	fprintf('%s: Failed to load data. Quitting\n ',mfilename);
	return
end



%rescale and save
F=figure('visible','off');




if ~exist(userConfig.subdir.WEBdir,'dir')
	mkdir(userConfig.subdir.WEBdir)
end

[im,threshLevel]=rescaleImage(im,rescaleThresh);

lastSection='LastCompleteSection.jpg';
imwrite(im,[userConfig.subdir.WEBdir,filesep,lastSection],'bitdepth',8)
close(F);

%Write histogram to disk
F=figure('visible','off');
sectionHist(im,threshLevel)
set(F,'paperposition',[0,0,6,3],'InvertHardCopy','off')
print('-dpng','-r100',[userConfig.subdir.WEBdir,filesep,'hist.png']);
close(F);



%Now loop through all depths and make a montage
F=figure('visible','off');
fprintf('Building montage images')
out=readMetaData2Stitchit;
if out.mosaic.numOpticalPlanes>1
	mos=rescaleImage(peekSection([ind,1],channel,0.1),rescaleThresh);
	mos=repmat(mos,[1,1,out.mosaic.numOpticalPlanes]);
	for ii=1:out.mosaic.numOpticalPlanes
		fprintf('.')
		mos(:,:,ii)=rescaleImage(peekSection([ind,ii],channel,0.1),rescaleThresh);
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
currentTime=datestr(now,'YYYY/mm/dd HH:MM:SS');
details = sprintf('Sample: %s (%d/%d) &mdash; %d &micro;m cuts &mdash; (%s)',...
	sample, currentSecNum, out.mosaic.numSections, out.mosaic.sliceThickness, currentTime);

endTime=estimateEndTime;

if out.mosaic.numOpticalPlanes>1
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
returnVal=system(sprintf('scp -r -q %s%s* %s', userConfig.subdir.WEBdir, filesep, sendTo));

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
		im(im>thresh)=thresh;
	end

	im = im ./(max(im(:)));
	im = im * 2^8;
	im = uint8(im);