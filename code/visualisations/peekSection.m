function varargout=peekSection(section,channel,resize)
% Crudely assemble a section from raw tiles and show on screen
%
% function [section,imStack,coords] = peekSection(section,channel,resize)
%   
% Purpose
% Crudely assemble a section from raw tiles and show on screen. This is a quick and 
% dirty way of viewing the stitched data. To aid visualisation, tiles are median 
% filtered and intensity adjusted. This process is slow on large images, so 
% resizing is done by default. Images are resized by default to be a little 
% bigger than screen. This allows for a little zooming in most scenarios. 
%
% Inputs
% section - one of: 1) a scalar (the z section in the brain)
%                   2) a vector of length two [physical section, optical section] 
%                   3) a cell array that's {tileStack, tileIndex}
%
% channel - scalar defining the channel to show. By default this is the first 
%           available channel.
%
% resize - a number from 0 to 1 that defines by how much we should 
%          re-scale the brain. optional. 
%
%
% Outputs (optional)
%  section - assembled section
%  imStack - the image stack used to make the section. 
%  coords  - the coordinates of each tile in the array
%
%
% Rob Campbell - Basel 2014


verbose=0; %set to 1 to assist in de-bugging

mosaicFile=getTiledAcquisitionParamFile;
param=readMetaData2Stitchit(mosaicFile);
userConfig=readStitchItINI;




if nargin<2 || isempty(channel)
    chans = channelsAvailableForStitching;
    channel=chans(1);
end

if nargin<3
    fullWidth = param.numTiles.X * param.tile.nRows;
    screenSize=get(0,'screenSize');
    resize=(screenSize(3)/fullWidth)*1.25;
    if resize>1
        resize=1;
    end
else
    if resize>1
        fprintf('Resize must be between 0 and 1\n')
        return
    end
end




%Load data if needed 
if ~iscell(section)
    if verbose, tic, end
    %Get the physical section and optical section if needed
    if length(section)<2
        section=zPlane2section(section);
    end

    if exist([userConfig.subdir.rawDataDir,filesep,'averageDir']) %Only illum correction if the directory is there. 
        doIlumCor=1;
    else
        doIlumCor=0;
    end

    if verbose
        fprintf('Loading tiles from section %d/%d channel %d\n',section,channel)
    end

    [im,tileIndex]=tileLoad([section,0,0,channel],doIlumCor); 


    if isempty(im) 
        fprintf('Failed to load data from section %d/%d channel %d.\n',section, channel)
        if nargout>0 
            varargout{1}=[];
        end
        if nargout>1
            varargout{2}=[];
        end
        return
    end


    if verbose
        timeIt=toc;
        fprintf('Tiles loaded in %0.1f s',timeIt)
    end
else
    im=section{1};
    tileIndex=section{2};
end

tileIndex=tileIndex(:,4:5); %Keep only the columns we're interested in


if resize<1
    im = imresize(im,resize);   
end


%-----------------------------------------------------------------------
%Begin stitching
if verbose, tic, end
%Flip arrays and stitch backwards. This reduces photo-bleaching artifacts
%*if the data haven't been intensity-corrected*. Because the TissueCyet 
%over-scan, reverse stitching won't help you if you don't pre-process the
%tiles. 
im=flip(im,3);
tileIndex=flipud(tileIndex);


%Now we can pre-allocate our image

pixelPositions=ceil(gridPos2Pixels(tileIndex,[param.voxelSize.X,param.voxelSize.Y]) * resize);
tileSize=size(im,1);

stitchedImage = ones(max(pixelPositions)+tileSize, 'uint16');
allocatedSize=size(stitchedImage);

%Super-simple stitcher
for ii=1:size(im,3)
    xPos = [pixelPositions(ii,2), pixelPositions(ii,2)+tileSize-1];
    yPos = [pixelPositions(ii,1), pixelPositions(ii,1)+tileSize-1];

    stitchedImage(yPos(1):yPos(2),xPos(1):xPos(2))=im(:,:,ii);
end


stitchedImage = medfilt2(stitchedImage);
if nargout==0 %Adjust the image only if we'll be displaying locally
    if verbose
        fprintf('; ')
    end
    fprintf('adjusting image intensity\n')

    stitchedImage =imadjust(stitchedImage);
end


%Flip sections if needed. 
st=userConfig.stitching;
if st.flipud
    stitchedImage=flipud(stitchedImage);
end
if st.fliplr
    stitchedImage=fliplr(stitchedImage);
end


if verbose
    timeIt=toc;
    fprintf('; stitching in %0.1f ms\n',timeIt*1E3)
end


%If the matrix has grown, we have a pre-allocation issue
if any(size(stitchedImage)-allocatedSize)
    fprintf(['Warning: stitched image has grown during stitching from pre-allocated size\n'...
             'Was %d by %d, now %d by %d\n'], allocatedSize, size(stitchedImage))
end





%-----------------------------------------------------------------------
%Output data if requested. 
if nargout>0
    varargout{1}=stitchedImage;
end

if nargout>1
    varargout{2}=im;
end

if nargout>2
    varargout{3}=tileIndex;
end

%If no output is requested we plot 
if nargout==0
    imagesc(stitchedImage)
    axis equal off
    colormap gray
end
