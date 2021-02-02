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
totalGB = (files(1).bytes * length(files)) / 1024^3;
totalGB = totalGB * 1.025; %Fudge factor to be sure we're over
if totalGB>4
    bigtiff=true;
else
    bigtiff=false;
end




%Create file name
paramFile=getTiledAcquisitionParamFile;
if startsWith(paramFile, 'recipe')
    % We have BakingTray Data
    stackFname = strcat(paramFile(8:end-4));
else
    error('Can not find recipe file')
end
chName=getChanNames(channel);
stackFname = sprintf('%s_chan_%02d%s.tiff',stackFname,channel,chName);


% Do the file write
if bigtiff
    writeBigTiff
else
    writeRegularTiff
end




% Internal functions follow
function chName = getChanNames(channel)
    % Obtain the channel name from the scan settings file
    if exist('scanSettings.mat','file')
        S=load('scanSettings');
        % Process channel name to ready it for insertion into file name
        chName = lower(S.scanSettings.hPmts.names{channel});
        chName = strrep(chName,' ','_');
        chName = ['_',chName];
    else
        chName='';
    end
end %function getChanNames



function writeRegularTiff
    imR=stitchit.tools.openTiff(fullfile(origDataDir,files(1).name));
    optionsR={'compression','none'};
    imwrite(imR,stackFname,'tiff','writemode','overwrite',optionsR{:})  

    for iiR=2:length(files)
        if mod(iiR,5)==0, fprintf('.'), end
        imR=stitchit.tools.openTiff(fullfile(origDataDir,files(iiR).name));
        imwrite(imR,stackFname,'tiff','writemode','append',optionsR{:})
    end
    fprintf('\n')
end %function writeRegularTiff


function writeBigTiff
    imB=stitchit.tools.openTiff(fullfile(origDataDir,files(1).name));
    optionsB=struct('big',true , 'overwrite', true, 'message', false);
    saveastiff(imB,stackFname,optionsB);

    optionsB=struct('big',true , 'overwrite', false, 'append', true, 'message', false);
    for iiB=2:length(files)
        if mod(iiB,5)==0, fprintf('.'), end
        imR=stitchit.tools.openTiff(fullfile(origDataDir,files(iiB).name));
        saveastiff(imR,stackFname,optionsB);
    end
    fprintf('\n')
end %function writeBigTiff

end %main function

