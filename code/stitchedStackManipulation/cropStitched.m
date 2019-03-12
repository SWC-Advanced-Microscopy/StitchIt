function cropStitched(stitchedDir,targetDir,rect)
% Produce copped stitched images from an existing stitched directory
%
% function cropStitched(stitchedDir,targetDir,rect)
%
%
% Purpose
% This is a very basic image cropping functions. It takes a directory containing
% stitched images and crops those images, saving them in targetDir. The input
% argument "rect" is the region to retain. Since this command is potentially 
% dangerous, it creates the cropped images in a separate directory and the user
% must manually replace the original files with the stitched files if that is what 
% they need. NOTE: This function deletes an existing directory if it will clash 
% with the one to be produced.
% 
% Inputs
% stitchedDir - string defining stitched data directory
% targetDir - a string defining the directory to save data to
% rect - vector indictaing area to retain 
%  [top left Y, top left X, width, height]
%
%
% Example
% crop all files from channel one of the full size images and put the cropped
% files in to a directory called "cropped_Ch1"
% cropStitched('stitchedImages_100/1','cropped_Ch1',[5E3,6E3,1E3,1E3])
%
%
% Rob Campbell


if strcmp(stitchedDir(end),filesep)
    stitchedDir(end)=[];
end

if strcmp(targetDir(end),filesep)
    targetDir(end)=[];
end

if ~exist(stitchedDir,'dir')
    error('Can not find %s',stitchedDir)
end

if exist(targetDir,'dir')
    fprintf('Wiping existing directory %s\n', targetDir)
    rmdir(targetDir,'s');
    mkdir(targetDir)
else
    mkdir(targetDir)
end


tifs = dir([stitchedDir,filesep,'*.tif']);
if isempty(tifs)
    error('No tiffs found in %s',stitchedDir);
else
    fprintf('Found %d images\n',length(tifs))
end



parfor ii=1:length(tifs)
    sourceIm = [stitchedDir,filesep,tifs(ii).name];
    fprintf('cropping %s\n', sourceIm)
    im=stitchit.tools.openTiff(sourceIm, [rect(2),rect(1),rect(3:4)]);
    imwrite(im,[targetDir,filesep,tifs(ii).name],'Compression','none')
end

%log the region we kept
save([targetDir,filesep,'cropped_rect_region.mat'],'rect')
