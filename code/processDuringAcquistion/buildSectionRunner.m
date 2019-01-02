function buildSectionRunner(chan,runInPath)
% Simple function that constantly looks for new data and sends them to the web if found
%
% function buildSectionRunner(chan)
%
% Purpose
% Sends new data to the web when completed directories are found. 
% Aborts when the FINISHED file appears
%
%

  if nargin<2
    runInPath=pwd;
  end

  cd(runInPath)

% This funtion may have been called from the system command line to run in the background from
% syncAndCrunch using something like: via /usr/bin/MATLABR2017b/bin/matlab -nosplash -nodesktop -r 'run("buildSectionRunner(2)")'
% In this case we must ensure that StitchIt is in the path. So we will test this first, and add it if needed, before carrying on. 
thisMfile = which(mfilename);
thisPath = fileparts(thisMfile);
MATLABpath = path;

if isempty(strfind(MATLABpath,thisPath))
    % buildSection runner is not in the path so neither is StitchIt.
    % Let's add StitchIt to the path
    
    StitchItPath = fileparts(thisPath);
    fprintf('Adding StitchIt to path at %s\n', StitchItPath)
    addpath(genpath(StitchItPath));

    fprintf('Running in directory: %s\n', pwd)
end




if nargin<1
    c=channelsAvailableForStitching;
    chan=c(1);
    fprintf('\n\n * No channel to plot defined.\n * Choosing channel %d to send to web\n\n', chan)
end

curN=generateTileIndex;


while ~exist('./FINISHED','file')
    t=generateTileIndex;
    if t~=curN
        curN=t;
        buildSectionPreview([],chan)
    end
    pause(5)
end


fprintf('Acquisition is FINISHED. %s is quitting\n', mfilename)
