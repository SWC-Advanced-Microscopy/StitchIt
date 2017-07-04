function varargout=stitched2RGB(directory,doMean,overwrite)
% Get a directory with stitched images as input
% produce a directory of RGB images from the 3 color channels
%
% function stitched2RGB(directory,doMean,overwrite)
%
% directory - [required] directory containing full file names.
% doMean - [optional] if 1, then just average layers and don't save as RGB
%          0 by default. So this is a merge of all three channels in the same layer.
%
% overwrite - optional. zero by default. If 1 we overwrite existing images. 
%             if 0 we skip RGB images that are already there. 
%
%
% Rob Campbell - Basel 2014


if nargin<2 | isempty(doMean)
  doMean=0;
end

if nargin<3
  overwrite=0;
end

%get a list of file names from channel 1  
files = dir([directory,filesep,'1',filesep,'*.tif']);

if isempty(files)
  fprintf('Cannot find files or directory\n')
  return
end

  
rgbDir=[directory,'_RGB'];
mkdir(rgbDir);


fprintf('Assembling RGB tiffs\n')
parfor ii=1:length(files)
  rgbFName = [rgbDir,filesep,files(ii).name];
  if exist(rgbFName,'file') & ~overwrite
    %fprintf('Skipping %s: already exists\n', rgbFName)
    continue
  end

  fprintf('Building %s\n', rgbFName);
  im = imread(sprintf('%s/%d/%s',directory,1,files(ii).name));
  im = repmat(im,[1,1,3]);

  okToSave=1;
  for jj=2:3

    %For some reason the different channels can have different sizes. 
    %Just in case this happens we catch the error here gracefully. 
    tmp=imread(sprintf('%s/%d/%s',directory,jj,files(ii).name));
    
    %QUICK HACK TO BUILD SPLEEN channels that are only slightly off
    %This may result in artifacts. Need to trace the cause of why this is
    %even needed
    if size(tmp,2)<size(im,2) & size(tmp,2)>(size(im,2)-3)
    tmp(end,size(im,2))=0;
      fprintf('Enlarging image a tad\n')
    end


    if any(size(tmp) - [size(im,1),size(im,2)])
      fprintf('Trying to add ch.%d (%d,%d) to %dx%d- Channels do not match in size. Skipping\n',...
       jj,size(tmp), size(im,1),size(im,2))
      okToSave=0;
      continue
    end
    im(:,:,jj) = tmp;
  end
  
  %Only save if we managed to build the tiff
  if okToSave
    if doMean
      im=single(im);
      im=uint16(mean(im,3)); %don't save RGB but as average of all three channels. 
    end

    imwrite(im,rgbFName)
  end
  
end

fprintf(' Done\n')

