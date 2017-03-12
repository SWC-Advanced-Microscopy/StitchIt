function varargout=makeMontage(stitchDirectory,layer,displayFrames)
% Make a montage of images from a defined layer from a defined stitched data directory
%
% function makeMontage(stitchDirectory,layer,displayFrames)
%
% Purpose
% Make an image montage of all images from one layer. CAUTION: the size of the full 
% montage will depend on the sizes of the individual images. So if you use large 
% imgages things can quickly get out of control. Likely stitched images in the 5% region
% should be sufficient. see rescaleStitched.m to easily make a resized directory.
%
% 
% Inputs
% stitchedDirectory - [string] relative path to tif images
% layer - an integer that indicates which layer to draw. 1 by default. if -1 draw 
%         all layers. 
% displayFrames - optionally display images between [LOW,HIGH] (as in help montage). 
%                otherwise show all images
%
% Examples
% makeMontage('stitchedImages_05/2',2)
% makeMontage('stitchedImages_05/2')
%
%
% Rob Campbell - Basel 2015

if strmatch(stitchDirectory(end),filesep)
    stitchDirectory(end)=[];
end

tifs=dir([stitchDirectory,filesep,'*.tif']);

if isempty(tifs)
    error('Can not find tifs in %s\n',stitchDirectory)
end

if nargin<2
    layer=1;
end


tifs={tifs.name};

%remove all but the required optical section
for ii=length(tifs):-1:1
    if isempty(regexp(tifs{ii},sprintf('_%02d.tif$',layer))) & layer>0
        tifs(ii)=[];
    else
        tifs{ii} = [stitchDirectory,filesep,tifs{ii}];
    end
end

if nargin<3
    displayFrames=[1:length(tifs)];
end

%Make plots
fprintf('Making a montage of %d images\n',length(displayFrames))
H=montage(tifs,'DisplayRange',[0,1500],'Indices',displayFrames);



%optionally return handle
if nargout>0
    varargout{1}=H;
end