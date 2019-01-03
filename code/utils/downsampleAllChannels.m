function downsampleAllChannels(voxelSize)
% function downsampleAllChannels(voxelSize)
%
% Purpose
% Downsample all channels to MHD files with a voxel size defined by
% "voxelSize". If voxelSize is missing, we use 25 microns. Then copy
% all to a single directory.
%
% Inputs
% voxelSize - a scalar (25 by default) defining the target voxel
%             size of the resample operation.
%
%
% Rob Campbell - SWC, 2018
  

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

  % Now move all files to the destination directory
  for ii = 1:length(fnames)
    fprintf('Moving %s* to %s\n', fnames{ii}, dsDirName)
    movefile(fnames{ii}, dsDirName)
  end
  
  
