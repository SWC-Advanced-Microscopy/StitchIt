function [currentAcq,dirDetails] = findCurrentlyRunningAcquisition
% Finds the currently running acquisition on the system mount
% point and returns it as a structure with various other data.

  
    currentAcq = [];
    acqMountPoint = '/mnt/brainsaw'; % TODO - integrate into INI file

    d=dir(acqMountPoint);
    if length(d)<3
      return
    end

    n=1;
    for ii = 3:length(d)
      if d(ii).isdir
        t = getDirDetails(d(ii));
        if t.isAcqDir 
          dirDetails(n) = t;
          n=n+1;
        end
      end
    end


    % Sort by last update time of log file
    if length(dirDetails)>1
      [~,ind] = sort([dirDetails.secondsSinceLastAcqLogUpdate]);
      dirDetails = dirDetails(ind);
    end

    % Does the most recent one look like it could be an acquistion?
    if ~dirDetails(1).containsFINISHED && ...
          dirDetails(1).secondsSinceLastAcqLogUpdate<60*5
      currentAcq = dirDetails(1);
    end
    

function dirDetails = getDirDetails(dirStruct)

  pathToDir = fullfile(dirStruct.folder, dirStruct.name);
  dirDetails.isAcqDir=false;

  if exist(fullfile(pathToDir,'rawData'),'dir') && ...
        exist(fullfile(pathToDir,'scanSettings.mat'),'file')
    %Then this is overwhelming likely to be an acquisition directory.
    recipeFile = dir(fullfile(pathToDir,'recipe_*.yml'));
    if isempty(recipeFile)
      return
    end
    dirDetails.isAcqDir=true;
    recipeFile = recipeFile(end); % In case there are several
    
    dirDetails.samplePath = pathToDir;
    dirDetails.containsFINISHED = exist(fullfile(pathToDir,'FINISHED'), 'file')==2;

    d = dir(fullfile(pathToDir,'acqLog_*.txt'));
    dirDetails.secondsSinceLastAcqLogUpdate=inf;

    if ~isempty(d)
      d=d(end);
      deltaS = (now-d.datenum) * 24*60^2;
      if deltaS<0
        deltaS=0;
      end
      dirDetails.secondsSinceLastAcqLogUpdate = round(deltaS);
    end
    
    load(fullfile(pathToDir,'scanSettings.mat'));
    dirDetails.chanToDisplay = ...
        scanSettings.hChannels.channelDisplay(1);
    
  else
    %Otherwise bail out and indicate it's not an acq dir
    return
  end
  
