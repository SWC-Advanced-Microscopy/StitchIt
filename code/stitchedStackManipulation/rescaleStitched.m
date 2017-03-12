function rescaleStitched(stitchedDir,targetResize)
% Produce re-scaled (resized) stitched images from an existing stitched directory
%
% rescaleStitched(stitchedDir,targetResize)
%
%
% Purpose
% Take a stitched directory and resize the images to produce a new image 
% directory composed of smaller size images. targetResize should be a
% value between 1 and 100 (if the stitchedDir has full size images). If, say,
% stitchedDir has 50% size images and targetResize equals 25, then we reduce 
% the image size by half. No up-scaling is allowed. 
% 
% Inputs
% stitchedDir - string defining stitched data directory
% targetResize - number between 1 and 100
%
%
% Example
% rescaleStitched('stitchedImages_100',25)
%
%
% Notes
% Deletes existing directory name if it will clash with the one to be produced.
%
%
% Rob Campbell - Basel 2014
%
%
% Also see: resampleVolume

if strcmp(stitchedDir(end),filesep)
    stitchedDir(end)=[];
end

if ~exist(stitchedDir,'dir')
    error('Can not find %s',stitchedDir)
end


%Get the current data image resize value from the directory name
tok=regexp(stitchedDir,'.*_(\d+)','tokens');
if isempty(tok)
    error('Can not get image resize value from directory %s',stitchedDir);
end

currentResizeVal=str2num(tok{1}{1});

%By what fraction will we need to down-scale to achieve the correct image size?
rescaleValue = targetResize/currentResizeVal;

if rescaleValue>=1
    error('Up-scaling is not allowed')
end



%Now go through all the channels and resize, creating new directories as needed
newDirectoryName = sprintf('stitchedImages_%03d',targetResize);

if exist(newDirectoryName,'dir')
    fprintf('Deleting existing directory %s\n', newDirectoryName)
    rmdir(newDirectoryName,'s');
else
    mkdir(newDirectoryName)
end



%get the channels 
chans=dir(stitchedDir);
chans=chans([chans.isdir]);
for ii=length(chans):-1:1
    if isempty(regexp(chans(ii).name,'\d+')) %remove everything that's not a channel
        chans(ii)=[];
    end
end


%the channel names in a cell array of strings
chans = {chans.name};



fprintf('Found %d channels\n',length(chans))

for ii=1:length(chans)
    fprintf('Rescaling channel %s\n', chans{ii})

    sourceDir=[stitchedDir,filesep,chans{ii},filesep];
    tifs = dir([sourceDir,'*.tif']);
    if isempty(tifs)
        fprintf('No tiffs found in %s. Skipping.\n',sourceDir)
        continue
    end

    mkdir([newDirectoryName,filesep,chans{ii}]);    
    targetDir = [newDirectoryName,filesep,chans{ii},filesep];

    parfor jj=1:length(tifs)
        im=stitchit.tools.openTiff([sourceDir,tifs(jj).name]);
        imwrite(imresize(im,rescaleValue,'bicubic'), [targetDir,tifs(jj).name],'compression','none')
    end

end