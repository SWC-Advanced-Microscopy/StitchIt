function [out,imSizes]=checkStitchedImageSizes(sectionDir)
% Determine whether all stitched images in a directory are the same size
%
% function [out,imSizes]=checkStitchedImageSizes(sectionDir)
%
%
% Purpose
% If the user requested stitching based on stage coordinates then image sizes
% may differ by small amounts. We take this into account by cropping back the
% images to beyond the smallest expected size. This is reasonable to do because
% the required cropping is equivalent to only about 4 microns. This number was 
% obtained empirically on the Basel IMCF system in Jan 2015. Other systems may 
% differ and the properties of the Basel X/Y stage may even change with time. 
% Thus, this function checks if all images are sized correctly and reports back 
% if not. We check all images since it only takes a couple of seconds for 
% one thousand tiffs.
%
%
% Inputs
% sectionDir - string to the directory containing the stitched image files
% 
%
% Outputs
% out - the number of images that differ from the mode size. zero means all
%       images are the size.
% imSizes - an n-by-2 matrix of image sizes
%
%
% Rob Campbell - Basel 2014


if ~exist(sectionDir,'dir')
    fprintf('%s - section directory %s does not exist\n',...
        mfilename,sectionDir);
    return
end

if strcmp(sectionDir(end),filesep)
    sectionDir(end)=[];
end



tifs = dir([sectionDir,filesep,'*.tif']);

if isempty(tifs)
    fprintf('%s - no tiffs found in directory %s\n',...
        mfilename,sectionDir);
    return
end

if length(tifs)==1 %don't proceed if there's just one image
    out=0;
    imSizes=0;
    return
end


imSizes=ones(length(tifs),2);

parfor ii=1:length(tifs)
    I=imfinfo([sectionDir,filesep,tifs(ii).name]);  
    imSizes(ii,:) = [I.Width, I.Height];
end



%How many were not correctly sized?
out = abs(bsxfun(@minus,imSizes,mode(imSizes)));
out = sum(out,2);
out = length(find(out>0));
