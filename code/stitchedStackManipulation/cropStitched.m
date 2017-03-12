function cropStitched(stitchedDir,targetDir,rect)
% Produce copped stitched images from an existing stitched directory
%
% function cropStitched(stitchedDir,targetDir,rect)
%
%
% Purpose
% Take a stitched directory and crop the images, saving in targetDir. 
% rect is the region to retain. This command is potentially dangerous
% so we create the cropped images in a separate directory and the user
% must manually replace the original files with the stitched files if
% that is what they need.
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
% Notes
% Deletes existing directory name if it will clash with the one to be produced.
% Requires Alex Brown's, stitchit.tools.openTiff, which is part of goggleViewer
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
save([targetDir,filesep,'rect.mat'],'rect')