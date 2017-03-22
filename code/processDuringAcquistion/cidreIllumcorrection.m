function cidreIllumcorrection
% default post acquisition function. 
%
% You may write your own and have it run via the INI file. 
%
%
% Rob Campbell - Basel 2015


% destination folder is average dir of the average images
userConfig=readStitchItINI;
avDir = [userConfig.subdir.rawDataDir,filesep,userConfig.subdir.averageDir];
if ~exist(avDir,'dir')
    mkdir(avDir)
end

chansToStitch=channelsAvailableForStitching;

% calculate background model for illumination correction with CIDRE
for thisChan=chansToStitch 
    tic;
     % source directory name is adjusted to the Tissue way of saving
    source = sprintf('./rawData/*_0%i.tif',thisChan);
    cidre(source, 'destination',avDir);
    t=toc/60;
    fprintf('Time for one chanel is %i minutes\n',t);
end


