function stitchAllChannels(chansToStitch,stitchedSize,illumChans,combCorChans)
% Stitch all channels within the current sample directory
%
% function stitchAllChannels(chansToStitch,stitchedSize,combCorChans,illumChans)
%
%
% Purpose
% Stitches all data from all channels within the current sample directory. 
% Before stitching, this function performs all required pre-processing and builds 
% new illumination images if needed. This is a convenience function. To stitch 
% particular channels or sections see the stitchSection function. 
%
%
% Inputs
% chansToStitch - which channels to stitch. By default it's all available channels. 
% stitchedSize - what size to make the final image. 100 is full size and is 
%              the default. 50 is half size. stitchedSize may be a vector with a
%              range of different sizes to produced. e.g. [25,50,100]
% illumChans - On which channels to calculate the illumination correction if this hasn't 
%             already been done. By default it's the same a the chansToStich. 
% combCorChans - On which channels we will calculate the comb correction if this hasn't already been done. 
%             by default this is set to zero and no comb correction is done.
%
%
% Examples
% * stitch all available channels at full resolution.
% >> stitchAllChannels
%
% * stitch all available channels at 10% of their original size.
% >> stitchAllChannels([],10)
%
% * stitch only chans 1 and 3
% >> stitchAllChannels([],[],[1,3])
%
%
% Rob Campbell - Basel 2017
%
%
% Also see: stitchSection, generateTileIndex, preProcessTiles, collateAverageImages



%Bail out if there is no raw data directory in the current directory
config=readStitchItINI;
if ~exist(config.subdir.rawDataDir,'dir')
    fprintf('%s can not find raw data directory "%s". Quitting\n', ... 
        mfilename, config.subdir.rawDataDir)
    return
end


% Check input arguments
if nargin<1
    chansToStitch=[];
end

%See which channels we have avilable to stitch if the user didn't define this
if isempty(chansToStitch)
    chansToStitch=channelsAvailableForStitching;
    fprintf(['%s attempting to stitch channels: ', repmat('%d ',1,length(chansToStitch)),'\n'],...
     mfilename, chansToStitch)
end

if nargin<2 || isempty(stitchedSize)
    stitchedSize=100;
end

if nargin<3 || isempty(illumChans)
    illumChans=chansToStitch;
end

if nargin<4 || isempty(combCorChans)
    combCorChans=0;
end




%Loop through and stitch all requested channels
analysesPerformed = preProcessTiles(0, 'combCorChans', combCorChans,'illumChans', illumChans); %Ensure we have the pre-processing steps done

if analysesPerformed.illumCor || ~exist(fullfile(config.subdir.rawDataDir, config.subdir.averageDir),'dir');
    collateAverageImages([],true); % second inptut deletes original average directory before making a new one. Just being cautious. 
end


for thisChan=1:length(chansToStitch)
    stitchSection([],chansToStitch(thisChan),'stitchedSize',stitchedSize) %Stitch all sections from this channels
end
