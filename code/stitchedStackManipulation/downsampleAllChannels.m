function downsampleAllChannels(voxelSize,fileFormat)
% function downsampleAllChannels(voxelSize,fileFormat)
%
% Purpose
% Downsample all channels to MHD or TIFF files with a voxel size defined by
% "voxelSize". If voxelSize is missing, we use 25 microns. Then copy
% all to a single directory. 
%
% Inputs
% voxelSize - a scalar or vector(25 by default) defining the target voxel
%             size of the resample operation. If a vector it makes downsampled
%             stacks at each voxel size
% fileFormat - 'MHD' or 'TIFF'. TIFF by default
%
%
% Example
% downsampleAllChannels(10)
%
% Rob Campbell - SWC, 2018
%
% See also - resampleVolume, rescaleStitched

stitchedDataInfo=findStitchedData;
if isempty(stitchedDataInfo)
    fprintf('No stitched data found by %s. Quitting\n', mfilename)
    return
end

if nargin<1 || isempty(voxelSize)
    % Choose pyramid to make based upon the resolution
    if stitchedDataInfo.micsPerPixel<4 && stitchedDataInfo.zSpacingInMicrons<=10
        voxelSize=[50,25,10];
    else
        voxelSize=[50,25];
    end
end

if nargin<2 || isempty(fileFormat)
      fileFormat='tiff';
end


coreDownsampleDir = 'downsampled_stacks';
if ~exist(coreDownsampleDir,'dir')
    mkdir(coreDownsampleDir)
    fprintf('Making %s\n', coreDownsampleDir)
end

% Make sub-directories to hold downsampled stacks of a particular size
dsDirName={};
for ii=1:length(voxelSize)
    tDir = fullfile(coreDownsampleDir,sprintf('%03d_micron',voxelSize(ii)));
    if ~exist(tDir,'dir')
        fprintf('Making %s\n', tDir)
        mkdir(tDir)
    end
    dsDirName{ii}=tDir;
end



% Which channels are available?
chan = stitchedDataInfo.channelsPresent;

% Downsample those channels
for ii = 1:length(chan)
    tChan = chan(ii);
    fprintf('Making downsampled volume for channel %d\n', tChan)
    for jj=1:length(voxelSize)
        resampleVolume(tChan,voxelSize(jj),fileFormat,dsDirName{jj}); %Downsample
    end
end
