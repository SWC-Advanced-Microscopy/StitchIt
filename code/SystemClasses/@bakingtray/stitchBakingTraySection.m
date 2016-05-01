function varargout=stitchBakingTraySection
% stitch one section produced by baking tray. all files should be in current dir
%
%
% function stitched=stitchBakingTraySection
% 
% Notes
% stitched is a cell array of stitched channels. each cell contains a 
% stitched images. different cells for different channels.
%
%
% Inputs
% none
%
% Outputs
% optional Cell array of stitched images. saves images to disk
% 
% TEMPORARY FUNCTION

logFname=dir('*_log.txt');
if isempty(logFname)
	fprintf('No log file found\n')
	stitched=[];
	return
end
[stagePos,tileCoords]=readBakingLog(logFname.name);


t=dir('section_*.tif'); %each is a multi-page tiff
if isempty(t)
	fprintf('Found no tif images in directory %s\n',pwd)
	stitched=[];
	return
end

%There may be multiple channels
for ii=1:length(t)
	im{ii}=load3Dtiff(t(ii).name);
end

%get the recipe
R=readMetaData2Stitchit('../recipe.txt');


tileSize=R.mrowres*1E3; %microns %TODO: mrowres will be changed
overlap=R.overlap; %as a proportion

P=gridPos2Pixels(tileCoords,tileSize/size(im{1},1),tileSize*(1-overlap));

for ii=1:length(t)
	stitched{ii}=flipud(stitcher(im{ii},P)); %because by default it flips TV images
	saveFname = strrep(t(ii).name,'section','stitched');
	imwrite(stitched{ii},saveFname)
end





if nargout>0
	varargout{1} = stitched;
end
