function downsampleAllChannels(voxelSize,fileFormat)
% function downsampleAllChannels(voxelSize,fileFormat)
%
% Purpose
% Downsample all channels to MHD or TIFF files with a voxel size defined by
% "voxelSize". If voxelSize is missing, we use 25 microns. Then copy
% all to a single directory. 
%
% Inputs
% voxelSize - a scalar (25 by default) defining the target voxel
%             size of the resample operation.
% fileFormat - 'MHD' or 'TIFF'. TIFF by default
%
%
% Rob Campbell - SWC, 2018


stitchedDataInfo=findStitchedData;
if isempty(stitchedDataInfo)
    fprintf('No stitched data found by %s. Quitting\n', mfilename)
    return
end

if nargin<1 || isempty(voxelSize)
    voxelSize=25;
end

if nargin<2 || isempty(fileFormat)
      fileFormat='tiff';
end


dsDirName=sprintf('downsampledStacks_%d', round(voxelSize));


if ~exist(dsDirName,'dir')
    mkdir(dsDirName)
end

% Which channels are available?
chan = stitchedDataInfo.channelsPresent;

% Downsample those channels
for ii = 1:length(chan)
    tChan = chan(ii);
    fprintf('Making downsampled volume for channel %d\n', tChan)
    resampleVolume(tChan,voxelSize,fileFormat,dsDirName); %Downsample
end
