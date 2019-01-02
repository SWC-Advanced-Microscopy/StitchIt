function fnames=downsampleAllChannels(voxelSize)
% function downsampleAllChannels(voxelSize)
%
% Purpose
% Downsample all channels to MHD files with a voxel size defined by
% "voxelSize". If voxelSize is missing, we use 25 microns.


  if nargin<1
    voxelSize=25;
  end

  dsDirName=sprintf('downsampledMHD_%d', round(voxelSize));


  if ~exist(dsDirName,'dir')
    mkdir(dsDirName)
  end


  chan = channelsAvailableForStitching;
  fnames={};
  for ii = 1:length(chan)
    tChan = chan(ii);
    fprintf('Making downsampled volume for channel %d\n', tChan)
    [~,tFname]=resampleVolume(tChan,voxelSize);
    fnames{ii} = tFname;
  end
