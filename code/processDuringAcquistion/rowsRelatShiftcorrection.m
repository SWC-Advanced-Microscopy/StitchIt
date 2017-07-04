function rowsRelatShiftcorrection


% destination folder is average dir of the average images
userConfig=readStitchItINI;
avDir = [userConfig.subdir.rawDataDir,filesep,userConfig.subdir.averageDir];
if ~exist(avDir,'dir')
    mkdir(avDir)
end

% determine the number of available channels
chansToStitch=channelsAvailableForStitching;


 
% source directory name is adjusted to the Tissue way of saving
source = './rawData/';

% calculate shift for each tile in each section and make a txt 
ShiftCorrection(chansToStitch, source, avDir);




