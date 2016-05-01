function extractGFP(redChanDir,greenChanDir,outputDir,redThresh)
% Threshold red chan and divide green chan by it to extract GFP signal	
%
% function extractGFP(redChanDir,greenChanDir,outputDir)
%
%
% Purpose
% The GFP channel contains a lot of stuff (like inflamation-related signals) that
% are not from the GFP. We can get rid of a lot of this by dividing the green 
% channel by the red channel. This function does this and creates a new directory
% with the resulting images. The function works on stitched sections.
% 
% 
% Inputs
% redChanDir - the directory containing the red channel data
% greenChanDir - the directory containing the green channel data
% outputDir - where the GFP channel data will be saved
% redThresh - small values of the red channel need to be removed. This is the 
%             threshold used. This value is optional and a sensible default is 
%             provided by default. 
%
% Rob Campbell - Basel 2015

%Load all files in each channel directory. Number of tifs should be the same in each. 
%No real error checking right now. 

if ~strcmp(redChanDir(end),filesep)
	redChanDir(end+1)=filesep;
end
if ~strcmp(greenChanDir(end),filesep)
	greenChanDir(end+1)=filesep;
end
if strcmp(outputDir(end),filesep)
	redChanDir(end)=[];
end



red = dir([redChanDir,'*.tif']);
green = dir([greenChanDir,'*.tif']);

if isempty(red) | isempty(green)
	error('Failed to find files in one of those directories')
end

if length(red) ~= length(green)
	error('Number of tifs in red and green directories should match')
end

if exist(outputDir,'dir')
	fprintf('Deleting and remaking %s\n',outputDir)
	rmdir(outputDir,'s');
	mkdir(outputDir)
else
	fprintf('Making %s\n',outputDir)
	mkdir(outputDir)
end

if nargin<4
	redThresh=200;
end


parfor ii=1:length(red)
	R=single(imread([redChanDir,red(ii).name]));
	G=single(imread([greenChanDir,green(ii).name]));	

	f=find(R<redThresh);

	G(f)=0;

	GFP = uint16((G./R)*1000);

	imwrite(GFP,[outputDir,filesep,red(ii).name])

end