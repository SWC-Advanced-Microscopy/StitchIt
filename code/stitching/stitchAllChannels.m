function stitchAllChannels(chansToStitch,stitchedSize,combChans,illumChans)
% Stitch all channels within the current sample directory
%
% function stitchAllChannels(chansToStitch,stitchedSize,combChans,illumChans)
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
% combChans - the channels to use for comb correction if this hasn't already been done. 
%             by default it's the same as the channels to stitch. 
% illumChans - the channels to use for illumination correction if this hasn't 
%             already been done. By default it's the same a the chansToStich. 
%
%
% Examples
% * stitch all available channels at full resolution
% >> stitchAllChannels
%
% * stitch all available channels at 10% of their original size
% >> stitchAllChannels([],10)
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

%Bail out if we can't determin the acquisition system name
if determineStitchItSystemType<1
    %error message generated by determineStitchItSystemType
    return
end


% Check input arguments
if nargin<1
    chansToStitch=[];
end

if nargin<2 || isempty(stitchedSize)
    stitchedSize=100;
end

if nargin<3 || isempty(combChans)
    combChans=chansToStitch;
end

if nargin<4 || isempty(illumChans)
    illumChans=chansToStitch;
end


%See which channels we have avilable to stitch if the user didn't define this
if isempty(chansToStitch)
    chansToStitch=channelsAvailableForStitching;
end



%Loop through and stitch all requested channels
generateTileIndex; %Ensure the tile index is present
% analysesPerformed = preProcessTiles(0,combChans,illumChans); %Ensure we have the pre-processing steps done
% if analysesPerformed.illumCor
%     collateAverageImages
% end

for thisChan=chansToStitch 
    stitchSection([],thisChan,'stitchedSize',stitchedSize) %Stitch all sections from this channels
end
