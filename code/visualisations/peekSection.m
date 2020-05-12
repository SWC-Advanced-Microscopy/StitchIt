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
%           available channel. If channel is the string 'rgb', then peekSection
%           loads all available channels and assembles them into an RGB image.
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

doStageCoords = userConfig.stitching.doStageCoords; %If 1 use stage coords instead of naive coords


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


% Build an RGB image using a recursive function call
if ischar(channel) && ( strcmpi(channel,'rgb') || strcmpi(channel,'fratzl') )
    channel = channelsAvailableForStitching;
    if length(channel)==1
        [stitchedImage, im, tileIndex] = peekSection(section,channel,resize);
    else
        for ii=1:length(channel)
            [imData{ii},im,tileIndex]=peekSection(section,channel(ii),resize);
        end
        %Build RGB image (TODO: GENERALISE IT. HACK NOW FOR CHAN ORDER)
        stitchedImage = zeros([size(imData{1}),3],class(imData{1}));
        if length(channel)==4 
          channel = channel-1; % This is the hack
          channel(channel<1)=1; %So red and far red are both red
        else
          channel = 1:length(channel);
        end
        
        
        for ii=1:length(channel)
            stitchedImage(:,:,channel(ii)) = stitchedImage(:,:,channel(ii)) + imData{ii};
        end
        % Get mean of more than one red channel if needed
        if length(find(channel==1))>1
            stitchedImage(:,:,1) = stitchedImage(:,:,1) / length(find(channel==1));
        end

    parseOutputArgs(nargout);
    return
    end % if length(channel)==1
end %If doing RGB



%Load data if needed 
if ~iscell(section)
    if verbose, tic, end
    %Get the physical section and optical section if needed
    if length(section)<2
        section=zPlane2section(section);
    end

    % Only illum correction if the directory is there. 
    if exist(fullfile(userConfig.subdir.rawDataDir,'averageDir'),'dir') 
        doIlumCor=1;
    else
        doIlumCor=0;
    end

    if verbose
        fprintf('Loading tiles from section %d/%d channel %d\n',section,channel)
    end


    [imStack,tileIndex,stagePos]=tileLoad([section,0,0,channel],'doIlluminationCorrection', doIlumCor);
    imStack = flipud(imStack); % This is always necessary for the stitching to work

    if isempty(imStack) 
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



%-----------------------------------------------------------------------
%Begin stitching
if verbose, tic, end


% Get pixel positions for tiles
voxelSize = [param.voxelSize.X,param.voxelSize.Y];

if doStageCoords == 1
    pixelPositions = stagePos2PixelPos([stagePos.actualPos.X,stagePos.actualPos.Y],voxelSize);
elseif doStageCoords == 0
    pixelPositions = stagePos2PixelPos([stagePos.targetPos.X,stagePos.targetPos.Y],voxelSize);
else
    % We use the tile grid positions. This is how we used to do stitching before May 2020. 
    % the doStageCoords == 0 should give a result identical to this
    pixelPositions = ceil(gridPos2Pixels(tileIndex,voxelSize));
end

stitchedImage = stitcher(imStack,pixelPositions);

if resize<1
    stitchedImage = imresize(stitchedImage,resize);
end

stitchedImage = medfilt2(stitchedImage);
if nargout==0 %Adjust the image only if we'll be displaying locally
    stitchedImage =imadjust(stitchedImage);
end




if verbose
    timeIt=toc;
    fprintf('; stitching in %0.1f ms\n',timeIt*1E3)
end


parseOutputArgs(nargout);




function parseOutputArgs(outerFunctNargout)
    %-----------------------------------------------------------------------
    %Output data if requested
    if outerFunctNargout>0
        varargout{1}=stitchedImage;
    end

    if outerFunctNargout>1
        varargout{2}=im;
    end

    if outerFunctNargout>2
        varargout{3}=tileIndex;
    end

    %If no output is requested we plot 
    if outerFunctNargout==0
        if size(stitchedImage,3)==1
            imagesc(stitchedImage)
            colormap gray
        elseif size(stitchedImage,3)==3

            % Normalise
            stitchedImage = single(stitchedImage);
            for ii=1:size(stitchedImage,3)
                mx = stitchedImage(:,:,ii);
                mx = max(mx(:));
                if mx==0, continue, end
                stitchedImage(:,:,ii) = stitchedImage(:,:,ii) ./ mx;
            end

            % Scale each channel
            scaleFact = squeeze(mean(mean(stitchedImage,1),2)) * 4;
            for ii=1:3
                mx = scaleFact(ii);
                if mx==0, continue, end
                stitchedImage(:,:,ii) = stitchedImage(:,:,ii)/mx;
            end

            imshow(stitchedImage)
        end % size(stitchedImage,3)==1
        axis equal off
    end % outerFunct

end % function


end % peekSection
