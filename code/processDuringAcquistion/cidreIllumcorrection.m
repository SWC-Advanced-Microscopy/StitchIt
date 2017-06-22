function cidreIllumcorrection
% The function calculates background images to correct nonlinear
% illumination for Tissue Vision tiles.
% One model is calculated per 1 channel.
% The model.mat files are save in a rawData/avarageDir
% The following stitching then checks if this mat file exist or not and
% corrects the background if the file exist.
%
% stitchitConf.ini file needs to have doIlluminationCorrection = 1
% 
% Natalia Chicherova - Basel, 2017


% destination folder is average dir of the average images
userConfig=readStitchItINI;
avDir = [userConfig.subdir.rawDataDir,filesep,userConfig.subdir.averageDir];
if ~exist(avDir,'dir')
    mkdir(avDir)
end

% find the number of channels for stitching
chansToStitch=channelsAvailableForStitching;

% calculate background model for illumination correction with CIDRE
for thisChan=chansToStitch 
    tic;
     % source directory name is adjusted to the tissue cyte way of saving
    source = sprintf('./rawData/*_0%i.tif',thisChan);
    cidre(source, 'destination',avDir);
    t=toc/60;
    fprintf('Time for one chanel is %i minutes\n',t);
end


