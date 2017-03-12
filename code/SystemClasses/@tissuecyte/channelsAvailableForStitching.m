function availableChans=channelsAvailableForStitching(varargin)
% For user documentation run "help tileLoad" at the command line

config=readStitchItINI;

availableChans=[];
sectionDirs = dir(fullfile(config.subdir.rawDataDir,[directoryBaseName,'*']));

if isempty(sectionDirs)
    fprintf('ERROR: No TissueVision data directories found. Quitting.\n')
    return
end
tifs=dir(fullfile(config.subdir.rawDataDir,sectionDirs(1).name,'*.tif'));


for ii=1:length(tifs)
    tok=regexp(tifs(ii).name,'.*_(\d{2})\.tif','tokens');
    if isempty(tok)
        continue
    end
    availableChans=[availableChans,str2num(tok{1}{1})];
end


if isempty(availableChans)
    fprintf('%s Could not find any channels to stitch.\n',mfilename)
else
    availableChans=unique(availableChans);
end
