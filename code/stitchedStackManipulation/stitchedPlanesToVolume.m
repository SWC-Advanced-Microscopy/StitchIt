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
% INPUTS
% channel - which channel to resize (e.g. 1, 2, or 3)
%
%
% OUTPUTS [optional]
% fname -  The downsampled file name minus the extension.
% 
%
% EXAMPLES
% cd /path/to/experiment/root/dir
% stitchedPlanesToVolume(2)
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

origDataDir = fullfile(stitchedDir, num2str(channel));
if ~exist(origDataDir)
  fprintf('%s can not find directory %s\n', mfilename,origDataDir)
  return
end

files=dir(fullfile(origDataDir,'sec*.tif'));
if isempty(files)
  error('%s finds no tiffs found in %s',mfilename,origDataDir)
end



%Create file name
paramFile=getTiledAcquisitionParamFile;
if startsWith(paramFile, 'recipe')
    % We have BakingTray Data
    fname = strcat('ds', paramFile(8:end-4));
else
    % We have TissueVision
    fname = [regexprep(paramFile(1:end-4),'Mosaic_','ds')];
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

