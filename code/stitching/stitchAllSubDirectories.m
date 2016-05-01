function tifs=stitchAllSubDirectories(chansToStitch,stitchedSize,combChans,illumChans)
% Find all sub-directories within the current directory containing a mosiac file and stitch all data
%
% function tifs=stitchAllSubDirectories(chansToStitch,stitchedSize,combChans,illumChans)
%
% Purpose
% Stitches all data in a directory tree. Before stitching, function performs analysis and
% builds new illumination images if needed. 
%
% Inputs
% chansToStitch - which channels to stitch. By default it's all available channels. 
% stitchedSize - what size to make the final image. 100 is full size and is 
%              the default. 50 is half size. stitchedSize may be a vector with a
%              range of different sizes to produced. e.g. [25,50,100]
% combChans - the channels to use for comb correction if this hasn't already been done. 
%             by default it's the same as the channels to stitch. 
% illumChans - the channels to use for illumination correction if this hasn't 
%             already been done. By default it's the same a the chansToStich. 
%
%
% Rob Campbell - Basel 2014




config=readStitchItINI;
if ~exist(config.subdir.rawDataDir,'dir')
	fprintf('%s can not find directory %s. Quitting\n', mfilename, config.subdir.rawDataDir)
	return
end

% Find mosaic files (TODO: we we need the search command in the fist place?)
if ~isunix
	fprintf('\n\t*** %s is attempting to call a unix-specific command.\n\t*** You either need to switch to Mac/Linux or modify %s for your platform.\n\n',mfilename,mfilename)
	error('Can not proceed: you are not on Max or Linux and no Windows-specific code has been written for this action')
	%TODO: ==> here add Windows-specific code <==
	% See: 	http://www.mathworks.com/matlabcentral/fileexchange/1492-subdir--new-
	% 		http://ch.mathworks.com/matlabcentral/newsreader/view_thread/303929
else
	[status,results]=unix('find . -name ''Mosaic_*.txt'' '); % TODO: TissueVision-specific stuff that needs to vanish
end

if status~=0 || isempty(results)
	error('Unable to find Mosaic files')  % TODO: TissueVision-specific stuff that needs to vanish
end


files=regexp(results,'\n','split');
config=readStitchItINI;

%Remove lines that are likely to be sub-mosaic files (this inside section directories)
for ii=length(files):-1:1
	if ~isempty(regexp(files{ii},[config.subdir.rawDataDir,'.*'])) | isempty(files{ii})
		files(ii)=[];
	end
end


rootDirectory = pwd; %So we can return to it later


if nargin<1
	chansToStitch=[];
end

if nargin<2 || isempty(stitchedSize)
	stitchedSize=100;
end

if nargin<3 || isempty(combChans)
	combChans=chansToStitch;
end

if nargin<4 || isempty(illumChans)
	illumChans=chansToStitch;
end



for ii=1:length(files)
	cd(rootDirectory)

	[~,e]=regexp(files{ii},'.*/');
	thisDir = files{ii}(1:e);
	fprintf('Stitching %s\n',thisDir)

	cd(thisDir)

	baseName=directoryBaseName;


	%find the channels we have available
	sectionDirs = dir([config.subdir.rawDataDir,filesep,baseName,'*']);
	if isempty(sectionDirs)
		fprintf('No data directories found in %s. Skipping.\n',thisDir)
		continue
	end

	%see which channels we have
	tifs=dir([config.subdir.rawDataDir,filesep,sectionDirs(1).name,filesep,'*.tif']);
	if isempty(tifs)
		fprintf('No tifs in the first data directory at %s. Skipping all data in directory.\n',thisDir)
		continue
	end

	availableChans=[];
	for ii=1:length(tifs)
		tok=regexp(tifs(ii).name,'.*_(\d{2})\.tif','tokens');
		if isempty(tok)
			continue
		end
		availableChans=[availableChans,str2num(tok{1}{1})];
	end
	if isempty(availableChans)
		fprintf('Could not find any channels in %s. Skipping\n',thisDir)
		continue
	end

	availableChans=unique(availableChans);


	%Now loop through and stitch all requested channels
	if isempty(chansToStitch)
		doStitch(combChans,availableChans,availableChans,stitchedSize)
    else
		doStitch(combChans,illumChans,chansToStitch,stitchedSize)
    end


end


cd(rootDirectory)



%------------------------------------------------------------------------------------------
function doStitch(combChans,illumChans,chansToStitch,stitchedSize)
 	% doStitch - perform the stitching
	generateTileIndex; %Ensure the tile index is present
	analysesPerformed = preProcessTiles(0,combChans,illumChans); %Ensure we have the pre-processing steps done
	if analysesPerformed.illumCor
		collateAverageImages
	end

	for thisChan=chansToStitch 
		stitchSection([],thisChan,'stitchedSize',stitchedSize) %Stitch all required channels
	end
