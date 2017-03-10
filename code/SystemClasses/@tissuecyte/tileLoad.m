function [im,index]=tileLoad(obj,coords,doIlluminationCorrection,doCrop,doPhaseCorrection)
% Load raw tile data from TissueCyte experiment
%
% function [im,index]=tileLoad(coords,doIlluminationCorrection,doCrop)
%
% For user documentation run "help tileLoad" at the command line


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

averageSlowRows=userConfig.tile.averageSlowRows;



%Exit gracefully if data directory is missing 
param = obj.readMosaicMetaData(getTiledAcquisitionParamFile);
sectionDir=fullfile(userConfig.subdir.rawDataDir, sprintf('%s-%04d',param.SampleID,coords(1)));

if ~exist(sectionDir,'dir')
	fprintf('%s: No directory: %s. Skipping.\n',...
		mfilename,sprintf('%s',sectionDir))
	im=[];
	index=[];
	return
end

%Load the section-specific Mosaic file (better in case we've merged runs and file names differ)
paramFname=fullfile(sectionDir,sprintf('Mosaic_%s-%04d.txt',param.SampleID,coords(1)));
param=obj.readMosaicMetaData(paramFname); 


%Load tile index file or bail out gracefully if it doesn't exist. 
tileIndexFile=sprintf('%s%stileIndex',sectionDir,filesep);
if ~exist(tileIndexFile,'file')
	fprintf('%s: No tile index file: %s\n',mfilename,tileIndexFile)
	im=[];
	index=[];
	return
else
	index=readTileIndex(tileIndexFile);
end


%Find the index of the optical section and tile(s)
f=find(index(:,3)==coords(2)); %Get this optical section 
index = index(f,:);

indsToKeep=1:length(index);

if coords(3)>0
   	f=find(index(:,4)==coords(3)); %Row in tile array
   	index = index(f,:);
   	indsToKeep=indsToKeep(f);
end

if coords(4)>0
   	f=find(index(:,5)==coords(4)); %Column in tile array
   	index = index(f,:);
   	indsToKeep=indsToKeep(f);
end


%So now build the file name
fileIndex = index(:,1);

tifPrefix = obj.acqDate2TifPrefix(param.acqDate);


channel = coords(5);
if channel>3 | channel<1
	fprintf('Channel must be between 1 and 3. %d not valid.\n',channel)
	im=[];
	index=[];
	return
end

%Do not proceed if channel is missing
if ~all(index(:,5+channel))
	fprintf('%s: Channel %d is missing at least one tile. No tiles loaded!\n',mfilename,channel)
	im=[];
	index=[];
	return
end

%Preallocate in case we load multiple files
im = ones([param.rows, param.columns, length(fileIndex)], 'uint16');


loaded=zeros(1,size(im,3));
parfor ii=1:length(fileIndex)
    %If file doesn't exist we don't try to to load it 
    if ~(index(ii,5+channel))
    	fprintf('%s. Image %d/%d missing\n',mfilename,ii,length(fileIndex))
    	continue
    end

    raw_name = sprintf('%s%d_%02d.tif',tifPrefix,fileIndex(ii),coords(5)); %just the tiff file name
    thisFname = fullfile(sectionDir,raw_name); %with the directory
	tmp=stitchit.tools.openTiff(thisFname);
	if isempty(tmp)
    	im(:,:,ii) = 0;
    else
    	im(:,:,ii) = tmp;
    end
    loaded(ii) = 1;
end


%Handle missing tiles 
if sum(loaded)==0
	fprintf('Failed load any images!\n')
	im=[];
	tileIndex=[];
elseif sum(loaded)<size(im,3)
	fprintf('Failed load %d images\n!', size(im,3)-sum(loaded))
end



%--------------------------------------------------------------------
%Begin processing the loaded image or image stack


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
	cropBy=round(size(im,1) * userConfig.tile.cropProportion); 
	if verbose
		fprintf('Cropping images by %d pixels on each size\n',crop)
	end
    im  = im(cropBy+1:end-cropBy, cropBy+1:end-cropBy, :);
end


%Do illumination correction if requested to do so

if doIlluminationCorrection
	avDir = [userConfig.subdir.rawDataDir,filesep,userConfig.subdir.averageDir];

	if ~exist(avDir,'dir')
		fprintf('Please create grand averages with collateAverageImages\n')
	end

	aveTemplate = coords2ave(coords,userConfig);
	if doCrop
		 aveTemplate  = aveTemplate(cropBy+1:end-cropBy, cropBy+1:end-cropBy, :);
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
  		    oddRows=find(mod(index(:,5),2));
  		    if ~isempty(oddRows)
  		    	im(:,:,oddRows)=stitchit.tools.divideByImage(im(:,:,oddRows),aveTemplate(:,:,2)); 
  		    end

  		    evenRows=find(~mod(index(:,5),2)); 
  		    if ~isempty(evenRows)
  		    	im(:,:,evenRows)=stitchit.tools.divideByImage(im(:,:,evenRows),aveTemplate(:,:,1));
  		    end
  		case 'pool'
  			aveTemplate = mean(aveTemplate,3);
  			if averageSlowRows
  				aveTemplate = repmat(mean(aveTemplate,1), [size(aveTemplate,1),1]);
  			end
  			imagesc(aveTemplate)
  			im=stitchit.tools.divideByImage(im,aveTemplate);
  		otherwise
  			fprintf('Unknown illumination correction type: %s. Not correcting!', userConfig.tile.illumCorType)
  		end
		
end





%Calculate average filename from tile coordinates. We could simply load the
%image for one layer and one channel, or we could try odd stuff like averaging
%layers or channels. This may make things worse or it may make things better. 
function aveTemplate = coords2ave(coords,userConfig)

	layer=coords(2); %optical section
	chan=coords(5);

	fname = sprintf('%s/%s/%d/%02d.bin',userConfig.subdir.rawDataDir,userConfig.subdir.averageDir,chan,layer); %TODO: replace with fullfile
	if exist(fname,'file')
	    %The OS caches, so for repeated image loads this is negligible. 
	    aveTemplate = loadAveBinFile(fname); 
	else
		aveTemplate=[];
		fprintf('%s Can not find average template file %s\n',mfilename,fname)
	end

