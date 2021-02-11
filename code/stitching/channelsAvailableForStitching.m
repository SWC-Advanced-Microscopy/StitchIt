function availableChans=channelsAvailableForStitching
% Determine the number of available channels in the raw data that can be stitched
%
% function availableChans=channelsAvailableForStitching
%
% PURPOSE
% The meta-data file that stores the acquisition may not accurately reflect which 
% channels are actually present and available for stitching. e.g. Because the
% Orchestrator-Vivace software of TissueVision does not provide the option to 
% select channels and sometimes one is deleted after acquisition if it's not 
% needed. This function therefore looks in the raw data directory and figures
% out which channels are available. It returns this information as a vector of
% channel IDs. It achieves this by looking in the first section directory. So
% the assumption is that all section directories have the same number of channels. 
% There is no check as to whether this is really the case. 
%
% INPUTS
% None
%
% OUTPUTS
% availableChans - a vector of channel IDs available for stitching. 
%
%
% Rob Campbell - Basel 2017
%
% See also - stitchAllChannels


config=readStitchItINI;

availableChans=[];
sectionDirs = dir(fullfile(config.subdir.rawDataDir,[directoryBaseName,'*']));

if isempty(sectionDirs)
    fprintf('ERROR: No BakingTray data directories found. Quitting.\n')
    return
end

% Loop backwards through section directories until we find one with data
for ii = length(sectionDirs):-1:1
    pathToTiff = fullfile(config.subdir.rawDataDir,sectionDirs(ii).name);
    tifs=dir(fullfile(pathToTiff,'*.tif'));
    if isempty(tifs)
        continue
    else
        break
    end
end


imINFO=imfinfo(fullfile(pathToTiff,tifs(1).name));
SI=stitchit.tools.parse_si_header(imINFO(1),'Software');
availableChans=SI.channelSave;

if isempty(availableChans)
    fprintf('%s Could not find any channels to stitch.\n',mfilename)
end
