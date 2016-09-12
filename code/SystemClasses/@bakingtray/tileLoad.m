function [im,index]=tileLoad(obj,coords,doIlluminationCorrection,doCrop,doPhaseCorrection)
% For user documentation run "help tileLoad" at the command line
% 
% This function works without the need for generateTileIndex

%TODO: abstract the error checking?

%COMMON
%Handle input arguments
if length(coords)~=5
	error('Coords should have a length of 5. Instead it has a length of %d', length(coords))
end

if nargin<3
	doIlluminationCorrection=[];
end

if nargin<4
	doCrop=[];	
end

if nargin<5
	doPhaseCorrection=[];
end

verbose=0; %Enable this for debugging. Otherwise it's best to leave it off


%Load the INI file and extract default values from it
userConfig=readStitchItINI;

if isempty(doIlluminationCorrection)
	doIlluminationCorrection=userConfig.tile.doIlluminationCorrection;
end

if isempty(doCrop)
	doCrop=userConfig.tile.docrop; 
end
if isempty(doPhaseCorrection)
	doPhaseCorrection=userConfig.tile.doPhaseCorrection;
end

if isfield(userConfig.tile,'averageSlowRows') %if 1, we correct only intensity changes along the fast axis
	averageSlowRows=userConfig.tile.averageSlowRows;
else
	averageSlowRows=0;
end



%Exit gracefully if data directory is missing 
param = readMetaData2Stitchit(getTiledAcquisitionParamFile);
sectionDir=fullfile(userConfig.subdir.rawDataDir, sprintf('%s_%04d',param.sample.ID,coords(1)));

if ~exist(sectionDir,'dir')
	fprintf('%s: No directory: %s. Skipping.\n',...
		mfilename,sprintf('%s',sectionDir))
	im=[];
	positionArray=[];
	index=[];
	return
end
%/COMMON



%Load the tile position information
load(fullfile(sectionDir, 'tilePositions.mat')); %contains variable positionArray



%Find the index of the optical section and tile(s)
%BT
%TODO: right now we have no optical sections. Eventually we will and these will likely 
%be accessed by file name.

indsToKeep=1:size(positionArray,1);

if coords(3)>0
   	f=find(positionArray(:,2)==coords(3)); %Row in tile array
   	positionArray = positionArray(f,:);
   	indsToKeep=indsToKeep(f);
end

if coords(4)>0
   	f=find(positionArray(:,1)==coords(4)); %Column in tile array
   	positionArray = positionArray(f,:);
   	indsToKeep=indsToKeep(f);
end
%/BT
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% TODO: loads of this will be common across systems and should be abstracted away
%		in fact, should probably use tiffstack at some point as this would work better
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


%So now build the expected file name of the TIFF stack
sectionNum = coords(1);
planeNum = coords(2);
channel = coords(5);

sectionTiff = sprintf('section_%04d_plane_%02d_ch%02d.tif',sectionNum,planeNum,channel);
path2stack = fullfile(sectionDir,sectionTiff);
if ~exist(path2stack,'file')
	fprintf('%s - Can not find stack %s\n', mfilename, path2stack);
	im=[];
	positionArray=[];
	return
end

%BT
%Load the stack
im=loadTiffStack(path2stack,'frames',indsToKeep,'outputType','int16');
im=flipud(im); %TODO: Could do this at acquisition time


%---------------
%Build index output so we are compatible with the TV version (for now)
index = ones(length(indsToKeep),8);
index(:,1) = indsToKeep;
index(:,2) = sectionNum;
index(:,4) = positionArray(indsToKeep,2);
index(:,5) = positionArray(indsToKeep,1);
%---------------
%/BT



%--------------------------------------------------------------------
%Begin processing the loaded image or image stack

%COMMON
%correctPhase delay if requested to do so
if doPhaseCorrection
	corrStatsFname = sprintf('%s%sphaseStats_%02d.mat',sectionDir,filesep,coords(2));
	if ~exist(corrStatsFname,'file')
		fprintf('%s. phase stats file %s missing. \n',mfilename,corrStatsFname)
	else
		load(corrStatsFname);
		phaseShifts = phaseShifts(indsToKeep);
		im = applyPhaseDelayShifts(im,phaseShifts);
	end
end


%Crop if requested to do so
if doCrop
	cropBy=round(size(im,1)*userConfig.tile.cropProportion); 
	if verbose
		fprintf('Cropping images by %d pixels on each size\n',crop)
	end
    im  = im(cropBy+1:end-cropBy, cropBy+1:end-cropBy, :);
end


%Do illumination correction if requested to do so %TODO: *REALLY* need this stuff abstracted elsewhere
if doIlluminationCorrection
	avDir = fullfile(userConfig.subdir.rawDataDir,userConfig.subdir.averageDir);

	if ~exist(avDir,'dir')
		fprintf('Please create grand averages with collateAverageImages\n')
	end

	aveTemplate = coords2ave(coords,userConfig);
	if doCrop
		 aveTemplate = aveTemplate(cropBy+1:end-cropBy, cropBy+1:end-cropBy, :);
	end

	if isempty(aveTemplate)
		fprintf('Illumination correction requested but not performed\n')
		return
	end

	if verbose
		fprintf('Doing %s illumination correction\n',userConfig.tile.illumCorType)
	end

	switch userConfig.tile.illumCorType %loaded from INI file
	    case 'split'
	    	if averageSlowRows
	    		aveTemplate(:,:,1) = repmat(mean(aveTemplate(:,:,1),1), [size(aveTemplate,1),1]);
	    		aveTemplate(:,:,2) = repmat(mean(aveTemplate(:,:,2),1), [size(aveTemplate,1),1]);
	    	end

  		    %Divide by the template. Separate odd and even rows as needed		
  		    oddRows=find(mod(positionArray(:,5),2));
  		    if ~isempty(oddRows)
  		    	im(:,:,oddRows)=divideByImage(im(:,:,oddRows),aveTemplate(:,:,2)); 
  		    end

  		    evenRows=find(~mod(positionArray(:,5),2)); 
  		    if ~isempty(evenRows)
  		    	im(:,:,evenRows)=divideByImage(im(:,:,evenRows),aveTemplate(:,:,1));
  		    end
  		case 'pool'
  			aveTemplate = mean(aveTemplate,3);
  			if averageSlowRows
  				aveTemplate = repmat(mean(aveTemplate,1), [size(aveTemplate,1),1]);
  			end
  			im=divideByImage(im,aveTemplate);
  		otherwise
  			fprintf('Unknown illumination correction type: %s. Not correcting!', userConfig.tile.illumCorType)
  		end
		
end
%/COMMON

%Calculate average filename from tile coordinates. We could simply load the
%image for one layer and one channel, or we could try odd stuff like averaging
%layers or channels. This may make things worse or it may make things better. 
function aveTemplate = coords2ave(coords,userConfig)

	layer=coords(2); %optical section
	chan=coords(5);

	fname = sprintf('%s/%s/%d/%02d.bin',userConfig.subdir.rawDataDir,userConfig.subdir.averageDir,chan,layer);
	if exist(fname,'file')
	    %The OS caches, so for repeated image loads this is negligible. 
	    aveTemplate = loadAveBinFile(fname); 
	else
		aveTemplate=[];
		fprintf('%s Can not find average template file %s\n',mfilename,fname)
	end

