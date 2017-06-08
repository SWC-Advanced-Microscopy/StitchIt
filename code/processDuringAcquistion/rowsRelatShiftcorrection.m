function rowsRelatShiftcorrection


% destination folder is average dir of the average images
userConfig=readStitchItINI;
avDir = [userConfig.subdir.rawDataDir,filesep,userConfig.subdir.averageDir];
if ~exist(avDir,'dir')
    mkdir(avDir)
end

chansToStitch=channelsAvailableForStitching;

% calculate shift for each tile in each section and make a txt 
 
% source directory name is adjusted to the Tissue way of saving
source = './rawData/';



ShiftCorrection(chansToStitch, source, avDir);

% fprintf('Time for one chanel is %i minutes\n',t);



