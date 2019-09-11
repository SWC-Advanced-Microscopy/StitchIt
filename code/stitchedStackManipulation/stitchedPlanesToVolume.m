function varargout=stitchedPlanesToVolume(channel)
% Write stitched image planes from a channel to multi-page TIFF
%
% function fname=stitchedPlanesToVolume(channel)
%
% PURPOSE
% All planes of one channel to a multi-page TIFF. Only a good idea for smaller datasets. 
% For larger datasets see resampleVolume.m
%
%
% INPUTS (optional)
% channel - which channel to resize (e.g. 1, 2, or 3)
%
%
% OUTPUTS [optional]
% fname -  The downsampled file name minus the extension.
% 
%
% EXAMPLES
% * Convert channel 2 to a tiff stack
% cd /path/to/experiment/root/dir
% stitchedPlanesToVolume(2)
%
%
% * Convert all available channels to a tiff stack
% cd /path/to/experiment/root/dir
% stitchedPlanesToVolume
%
%
% Rob Campbell - SWC 2019
%
% Also see: rescaleStitched, resampleVolume



% Find a stitched image directory
stitchedDataInfo=findStitchedData;
if isempty(stitchedDataInfo)
  fprintf('%s Finds no stitched data to resample.\n',mfilename)
  return
end

stitchedDataInd=1;
stitchedDir = stitchedDataInfo(stitchedDataInd).stitchedBaseDir;

% If no inputs provided, loop through all available channels with a
% recursive function call
if nargin<1 || isempty(channel)
  tChans = stitchedDataInfo.channelsPresent;
  for ii=1:length(tChans)
    fprintf('Converting channel %d to a TIFF stack\n',tChans(ii))
    stitchedPlanesToVolume(tChans(ii));
  end
  return
end


origDataDir = fullfile(stitchedDir, num2str(channel));
if ~exist(origDataDir)
  fprintf('%s can not find directory %s\n', mfilename,origDataDir)
  return
end

files=dir(fullfile(origDataDir,'sec*.tif'));
if isempty(files)
  error('%s finds no tiffs found in %s',mfilename,origDataDir)
end

% Do not proceed if the final stack will hit the bigtiff limit 
totalGB = (files(1).bytes * length(files)) / 1028^3;
if totalGB>4
  fprintf('Final stack will be %0.2f GB and so exceed the 4GB TIFF limit.\n', totalGB)
  return
end

% Do not proceed if the final stack can not be loaded into RAM
freeGB = (stitchit.tools.systemMemStats/1024^2);
if totalGB > freeGB
  fprintf('Final stack will take up %0.2f GB of RAM and only %0.2f GB are free. Not proceeding.\n', totalGB,freeGB)
  return
end




%Create file name
paramFile=getTiledAcquisitionParamFile;
if startsWith(paramFile, 'recipe')
    % We have BakingTray Data
    fname = strcat(paramFile(8:end-4));
else
    % We have TissueVision
    fname = [regexprep(paramFile(1:end-4),'Mosaic_','')];
end
fname = sprintf('%s_chan_%02d.tiff',fname,channel);


im=stitchit.tools.openTiff(fullfile(origDataDir,files(1).name));
options={'compression','none'};
imwrite(im,fname,'tiff','writemode','overwrite',options{:})  


for ii=2:length(files)
  fprintf('.')
  im=stitchit.tools.openTiff(fullfile(origDataDir,files(ii).name));
  imwrite(im,fname,'tiff','writemode','append',options{:})
end

