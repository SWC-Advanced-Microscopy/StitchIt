function availableChans=channelsAvailableForStitching(obj)
% For user documentation run "help tileLoad" at the command line


config=readStitchItINI;

availableChans=[];
sectionDirs = dir(fullfile(config.subdir.rawDataDir,[directoryBaseName,'*']));

if isempty(sectionDirs)
    fprintf('ERROR: No BakingTray data directories found. Quitting.\n')
    return
end
tifs=dir(fullfile(config.subdir.rawDataDir,sectionDirs(1).name,'*.tif'));

imINFO=imfinfo(fullfile(tifs(1).folder,tifs(1).name));
SI=obj.parse_si_header(imINFO(1),'Software');
availableChans=SI.channelSave;

if isempty(availableChans)
    fprintf('%s Could not find any channels to stitch.\n',mfilename)
end
