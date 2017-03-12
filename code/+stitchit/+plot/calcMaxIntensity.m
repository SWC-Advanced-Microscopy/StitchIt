function varargout = calcMaxIntensity(stitchedDir,sectionRange,doPlot)
% Calculate maximum intensity projection using a set of stitched images
%
% function maxImage = calcMaxIntensity(stitchedDir,sectionRange,doPlot)
%
% Purpose
% Calculate the maximum intensity projection of a stitched data set from one channel. 
% Images are loaded in parallel and incrementally, so arbitrarily large stacks can be processed. 
%
%
% Inputs
% stitchedDir - A sring defining the location of the stitched images for that channel. So the 
%                relative path to the directory that contains the stitched image files.
% sectionRange - optional. A vector defining which sections to use. By default all sections 
%                 are used. e.g. to use every 10th of 200 sections do 1:10:200
% doPlot - false by default. If true, we ploth max image to screen. You might need to re-scale
%           it to see anything.
%
% 
% Outputs
% maxImage - the maximum intensity image.
%
%
%
% Examples
% To get the maximum intensity projection of channel 1 from the the full stitched image stack:
% maxCh1 =  maxIntensityPlot('stitchedImages_100/1');
%
% To use only every 10th section of 310 sections
% maxCh1 =  maxIntensityPlot('stitchedImages_100/1',1:10:310);
%
%
%
% Rob Campbell - Basel 2015

if strcmp(stitchedDir(end),filesep)
    stitchedDir(end)=[];
end

if ~exist(stitchedDir,'dir')
    error('Directory %s not found',stitchedDir)
end


tifs = dir([stitchedDir,filesep,'*.tif']);


if isempty(tifs)
    error('No tifs found in %s', stitchedDir)
end


%Select a restricted range if needed
if nargin<2
    sectionRange = 1:length(tifs);
end

tifs = tifs(sectionRange);

if nargin<3
    doPlot=false;
end


%Read in the images in batches and in parallel in order to use little RAM and be quick
G=gcp;
nImages = length(tifs);

numBatches = floor(nImages/G.NumWorkers);


info=imfinfo([stitchedDir,filesep,tifs(1).name]);

imClass = ['uint',num2str(info.BitsPerSample)];


imSize = [info.Height,info.Width];
maxImage = zeros(imSize,imClass); %The max imag

fprintf('Producing max intensity image')
for ii=0:numBatches-1

    ind = (1:G.NumWorkers) + G.NumWorkers*ii;

    %pre-allocated image
    tmp = zeros([imSize,length(ind)],imClass);
    tmpSize=size(tmp);
    tmpSize=tmpSize(1:2); %because we will want to verify that all loaded images are this size


    fprintf('.')
    parfor jj=1:length(ind)
        im=stitchit.tools.openTiff([stitchedDir,filesep,tifs(ind(jj)).name]);
        if ~all(size(im)==tmpSize)
            error('Images appear to be of different sizes. Did you re-size a subset of them?')
        end
        tmp(:,:,jj)=im;
    end

    tmp=max(tmp,[],3);
    maxImage = max(cat(3,maxImage,tmp),[],3);

end

%Now finish off
ind = [ind(end)+1 : length(tifs)];

%pre-allocated image
tmp = zeros([imSize,length(ind)],imClass);

parfor jj=1:length(ind)
    tmp(:,:,jj)=imread([stitchedDir,filesep,tifs(ind(jj)).name]);
end

tmp=max(tmp,[],3);
maxImage = max(cat(3,maxImage,tmp),[],3);
fprintf('\n')


if doPlot
    clf
    imagesc(maxImage)
    axis equal off
end


if nargout>0
    varargout{1}=maxImage;
end
