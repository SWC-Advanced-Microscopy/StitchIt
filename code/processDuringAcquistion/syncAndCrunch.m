function syncAndCrunch(localDir,serverDir,combCorChans,illumChans,removeChan3,chanToPlot)
% download data from server, pre-process, and send to WWW
%
% function syncAndCrunch(localDir,serverDir,combCorChans,illumChans,removeChan3,chanToPlot)
%
%
% Purpose
% Perform tile index generation, analysis (mean image and comb corr), 
% collate average images, then build last section and send to web. 
%
% Inputs
% localDir - the full path to the local directory which will house the data directory. 
% serverDir - the full path to data directory on the server
% combCorChans - vector defining which channels will contribute to comb correction.
%               if empty or missing 1:2. To not do the correction set to 0.
% illumChans - vector defining which channels will have mean images calculated.
%               if empty or missing 1:2. To not calculate set to zero. These chans are stitched at the end
% removeChan3 - zero by default. If 1, we wipe channel 3 on the server and local directories.
%               This is an option because the TissueVision does not let us choose which channels
%               to save.
% chanToPlot - which channel to send to web (2 by default). If zero, don't do the web plots. 
%
%
% Example
% The following will create the directory AE033 in /mnt/data/TissueCyte/AwesomeExperiments
% and sync data to it.
%
% LDir = '/mnt/data/TissueCyte/AwesomeExperiments'
% SDir = '/mnt/tvbuffer/Data/AwesomeExperiments/AE033'
% syncAndCrunch(LDir,SDir,1:3,1:3,0,1)
% 
%
% NOTE! 
% The string for the local directory argument is NOT:
% '/mnt/data/TissueCyte/AwesomeExperiments/AE033'
% It is: 
% '/mnt/data/TissueCyte/AwesomeExperiments/''
% However, syncAndCrunch will attept to catch this error.
%
%
%
% Rob Campbell - Basel 2015


%Input argument error checks
if ~ischar(localDir)
  fprintf('ERROR: localDir should be a string\n')
  return
end
if ~exist(localDir,'dir')
  fprintf('ERROR: Cannot find directory %s defined by localDir\n',localDir)
  return
end
if ~ischar(serverDir)
  fprintf('ERROR: serverDir should be a string\n')
  return
end
if ~exist(serverDir,'dir')
  fprintf('ERROR: can not find directory %s defined by serverDir\n',serverDir)
  return
end

%Remove trailing fileseps
if strcmp(localDir(end),filesep)
  localDir(end)=[];
end
if strcmp(serverDir(end),filesep)
  serverDir(end)=[];
end

%Bail out of the two are the same
if strcmp(serverDir,localDir)
  fprintf('ERROR: serverDir and localDir are the same\n')
  return
end


if nargin<3 | isempty(combCorChans)
  combCorChans=1:2;
end
if ~isnumeric(combCorChans)
  fprintf('ERROR: combCorChans should be a numeric scalar or vector\n')
  return
end

if nargin<4 | isempty(illumChans)
  illumChans=1:2;
end
if ~isnumeric(illumChans)
  fprintf('ERROR: illumChans should be a numeric scalar or vector\n')
  return
end

if nargin<5 | isempty(removeChan3)
  removeChan3=0;
end
if ~isnumeric(removeChan3)
  fprintf('removeChan3 should be numeric (0 or 1)\n')
  return
end
if removeChan3~=0 & removeChan3~=1
  fprintf('removeChan3 should be 0 or 1\n')
  return
end

if nargin<6 | isempty(chanToPlot)
  chanToPlot=2;
end
if ~isnumeric(chanToPlot) || ~isscalar(chanToPlot)
  fprintf('chanToPlot should be a numeric scalar\n')
  return
end





%Report if StitchIt is not up to date
logFileName='StitchIt_Log.txt'; %This is the file to which error messages will be written
try 
  stitchit.updateChecker.checkIfUpToDate;
catch
  stitchit.tools.logger(lasterror,logFileName)
  fprintf('Failed to check if StitchIt is up to date. Error written in %s\n',logFileName)
end



if removeChan3
  fprintf('Will be removing channel 3\n')
end



% The experiment name is simply the last directory in the serverDir:
% TODO: is that really the best way of doing things? <--

%If local dir contains the experiment directory at the end,  we should remove this and raise a warning
[~,expName,extension] = fileparts(serverDir);

[localDirMinusExtension,localTargetRoot] = fileparts(localDir);

if strcmp(localTargetRoot,expName)
  fprintf('\nNOTE: Stripping %s from localDir. see help %s for details\n\n',expName,mfilename);
  localDir = localDirMinusExtension;
end

if ~isWritable(localDir)
  fprintf('WARNING: you appear not to have permissions to write to %s. syncAndCrunch may fail.\n',localDir)
end
if ~isWritable(serverDir)
  fprintf('WARNING: you appear not to have permissions to write to %s. You may not be able to delete channels during acquisition.\n',serverDir)
end


expDir = fullfile(localDir,expName,extension); %we add extension just in case the user put a "." in the file name


%Initial INI file read
config=readStitchItINI;


%Do an initial rsync 
if removeChan3
  fprintf('Removing channel 3 from server\n')
  unix(sprintf('find %s -name ''*_03.tif'' -exec rm -f {} \\;',serverDir));
end


%copy text files and the like into the experiment root directory
if ~exist(expDir,'dir')
  mkdir(expDir)
end

unix(sprintf('rsync %s %s%s*.* %s',config.syncAndCrunch.rsyncFlag, serverDir,filesep,expDir));


rawDataDir = [expDir,filesep,config.subdir.rawDataDir];
fprintf('Getting first batch of data from server and copying to %s\n',rawDataDir)


cmd=sprintf('rsync %s %s%s %s',config.syncAndCrunch.rsyncFlag, serverDir, filesep, rawDataDir);
fprintf('Running:\n%s\n',cmd)
unix(cmd);

cd(expDir) %The directory where we are writing the experimental data
if finished
  %If already finished when we start then we don't send Slack messages at the end. 
  expAlreadyFinished=true;
else
  expAlreadyFinished=false;
end


pathToRawData=[expDir,filesep,config.subdir.rawDataDir,filesep]; %The raw data directories are kept here

%Now enter a loop in which we alternate between pulling in data from the server and analysing
%those data
lastDir='';

%TODO:  We could use parfeval to keep rsync running the whole time in a loop that stops only when a 
%       file called "FINISHED" is made in the experiment directory also remove chan 3 in this loop.

sentPlotwarning=0; %To record if warning about plot failure was sent
sentConfigWarning=0; %Record if we failed to read INI file
sentCollateWarning=0;
sentWarning=0;




%----------------------------------------------------------------------------------------
% start big while loop that runs during acquisition
while 1
  %If a file called "FINISHED" is present then we break and crunch. 
  %The loop automatically produces this file after the crunching
  %phase if all sections are acquired. 
  %Due to the continue statement, this doesn't work if placed at the end of the loop. Loop never breaks.
  if finished 
    break
  end

  %read tvMat config file
  try
    config=readStitchItINI;
  catch
    if ~sentConfigWarning %Do not re-send using notify
      L=lasterror;
      stitchit.tools.notify(sprintf('%s Failed to read INI file with error %s', generateMessage('negative'), L.message))
      sentConfigWarning=1;
    else
      L=lasterror;
      fprintf('Failed to read INI file with error %s\n', L.message)
    end
    stitchit.tools.logger(L,logFileName)
  end %try/catch



  %Bail out if the server directory is missing
  if ~exist(serverDir,'dir')
    msg=sprintf('Server directory %s missing. Quitting.', serverDir);
    fprintf([msg,'\n'])
    stitchit.tools.notify([generateMessage('negative'), ' ', msg]);
    return
  end

  
  %Remove channel 3 on server
  if removeChan3
    cmd=sprintf('find %s -name ''*_03.tif'' -exec rm -f {} \\;',serverDir);
    fprintf('Removing channel 3 from server:\n%s\n\n',cmd)
    [returnStatus,msg]=unix(cmd);
    if returnStatus~=0 && ~sentWarning
      fprintf('Failed to remove chan 3 from server\n')
      %Truncate message if it's really long
      if length(msg)>200
        msg(201:end)=[];
      end
      stitchit.tools.notify([generateMessage('negative'),' chan 3 removal on server failed with error: ',msg])
      sentWarning=1;
    end
  end 
  

  %Pull data from TV buffer server to analysis machine
  params = readMetaData2Stitchit;
  numSections = params.mosaic.numSections;
  %Get the number of acquired directories so far
  numDirsAcquired = length(returnDataDirs(rawDataDir));

  fprintf('Getting files for section %d/%d from server\n', numDirsAcquired, numSections)
  try
    [returnStatus,msg]=unix(sprintf('rsync %s %s%s*.* %s', config.syncAndCrunch.rsyncFlag, serverDir,filesep, expDir)); %files with extensions copied to experiment dir
    [returnStatus,msg]=unix(sprintf('rsync %s %s%s %s', config.syncAndCrunch.rsyncFlag, serverDir, filesep, rawDataDir));
  catch
    if returnStatus~=0 && ~sentWarning
      stitchit.tools.notify([generateMessage('negative'),' rsync failed in ',localDir,' Attempting to continue'])
      sentWarning=1;
    end
  end 

  %first remove chan 3 data if the user asked for this
  if removeChan3
    try
      cmd=sprintf('find %s%s%s* -name ''*_03.tif'' -exec rm  -f {} \\;',...
            expDir,filesep,config.subdir.rawDataDir);
      fprintf('Removing local copy of channel 3:\n%s\n\n',cmd)
      [returnStatus,msg]=unix(cmd);
    catch
      if returnStatus~=0 && ~sentWarning
        stitchit.tools.notify([generateMessage('negative'),' chan 3 removal failed with error: ',msg,' Attempting to continue.'])
        sentWarning=1;
      end
    end
  end


  %Do not proceed until we have at least one finished section
  dataDirs=returnDataDirs(rawDataDir);

  if length(dataDirs)<=1
    fprintf('Waiting. No finished sections.')
    for ii=1:10
      fprintf('.')
      pause(3)
    end
    pause(2)
    continue
  end


  %Find the most recent data directory
  sectionDir=dataDirs(end).name;
  if isempty(sectionDir) %If the section directory is empty we pause and loop back around
    pause(5)
    continue
  else
    thisDir=sectionDir;
    %TODO: this is wrong - it's the previously completed directory 
    tifsInDir = dir([pathToRawData,thisDir,filesep,'*.tif']); %tiffs in current dir
    fprintf('Now %d tifs in current section directory: %s\n',length(tifsInDir), thisDir)
  end


  %Only attempt to crunch new data, etc, if we have added a new directory or if this is the last directory
  if strcmp(lastDir,thisDir) && length(dataDirs)<params.mosaic.numSections
    fprintf('Waiting')
    waitSecs=15;
    for ii=1:waitSecs
      fprintf('.')
      pause(1)
    end
    fprintf('\n')
    continue %so we don't keep re-making the same images on web
  end



  try 
    [numCompleted,indexPresent]=generateTileIndex([],[],0);  %GENERATE TILE INDEX
    if numCompleted>0
      fprintf('Adding tile index files to %d raw data directories\n',numCompleted)
    end
  catch
    L=lasterror;
    stitchit.tools.notify(sprintf('%s Failed to generateTileIndex with:\n%s\n',...
      generateMessage('negative'), L.message))
    stitchit.tools.logger(L,logFileName)
  end %try/catch

  fprintf('\nCRUNCHING newly found completed data directories\n')



  analysesPerformed = preProcessTiles(0,combCorChans,illumChans,0); %PRE-PROCESS TILES


  if isempty(analysesPerformed)
    fprintf('Returning to start of loop: tile analysis failed!\n')
    pause(15)
    continue
  else
    fprintf('Assigning this as the last finished section\n')
    lastDir=thisDir; %The last directory to have been processed. 
  end


  if analysesPerformed.illumCor
    try
      collateAverageImages %GENERATE GRAND-AVERAGE IMAGES (but these keep getting over-written)
    catch
      L=lasterror;
      if ~sentCollateWarning %So we don't send a flood of messages
        stitchit.tools.notify([generateMessage('negative'),' Failed to collate average images. ',L.message])
        sentCollateWarning=1;
      else
        fprintf(['Failed to collate. ',L.message]) 
      end
      stitchit.tools.logger(L,logFileName)
    end %try/catch
  end


  if chanToPlot==0
    fprintf('Not sending preview images to web\n')
  else
    fprintf('Building images and sending to web\n') 
      try 
          buildSectionPreview([],chanToPlot); %plot last completed section as per the trigger file
      catch
        L=lasterror;
          if ~sentPlotwarning %So we don't send a flood of messages
            stitchit.tools.notify([generateMessage('negative'),' Failed to plot image. ',L.message])
            sentPlotwarning=1;
          else
            fprintf(['Failed to plot image. ',L.message])
          end 
          stitchit.tools.logger(L,logFileName)
      end %try/catch
  end



  %Wait until the last section is completed before quitting
  if length(indexPresent)==numSections && indexPresent(end) %Will fail if final section is missing a tile
      fprintf('\n** All sections have been acquired. Beginning to stitch **\n')
    unix('touch FINISHED');
    if ~all(indexPresent)
      unix('touch ORIG_DATA_HAD_MISSING_TILES');
    end
  elseif length(dir(fullfile(rawDataDir,'trigger','*.tr2'))) == numSections
      fprintf('\n** All sections have been acquired. Beginning to stitch **\n')
    unix('touch FINISHED');
    unix('touch ORIG_DATA_LIKELY_HAD_MISSING_TILES'); %Very likely contains missing tiles
  end
  

end
%----------------------------------------------------------------------------------------



% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
%Run post-acquisition stuff

% Find the function that we will run after acquisition
config=readStitchItINI; %re-read the config file
if config.syncAndCrunch.postAcqFun==0
  postAcqFun='postAcq';
else
  if exist(config.syncAndCrunch.postAcqFun,'file')
    postAcqFun=config.syncAndCrunch.postAcqFun;
  else
    fprintf('No function file %s\n. Defaulting to postAcq\n',config.syncAndCrunch.postAcqFun)
    postAcqFun='postAcq'; %Default post-acquisition function
  end
end


% To avoid sending slack messages if the user has begun the analysis on data that already have a "finished" file
if ~expAlreadyFinished 
  stitchit.tools.notify(sprintf('%s Acquisition finished. Beginning stitching of %s.',generateMessage('positive'),expName))
end

try
  stitchit.tools.warnLowDiskSpace(localDir,90)
  eval(postAcqFun) %Run the post-acquisition function
  success=true;
catch
  if ~expAlreadyFinished
    L=lasterror;
    stitchit.tools.notify([generateMessage('negative'),' Stitching failed. ',L.message])
    stitchit.tools.logger(L,logFileName)
  end
  success=false;
end

if ~expAlreadyFinished && success
  stitchit.tools.notify(sprintf('%s %s has been stitched.',generateMessage('positive'),expName))
end

stitchit.tools.notify('syncAndCrunch finished')


%-------------------------------------------------------------------------------------
function out = finished
  %Return true if the finished file is present. false otherwise.
  config=readStitchItINI;
  if exist('FINISHED','file') || ...
    exist('FINISHED.txt','file') || ...
    exist(fullfile(config.subdir.rawDataDir,'FINISHED'))  || ...
    exist(fullfile(config.subdir.rawDataDir,'FINISHED.txt'),'file')

    out = true;
  else
    out = false;
  end



function dataDirs=returnDataDirs(rawDataDir)
  %return directories that are likely section directories based on the name
  potentialDirs=dir([rawDataDir,filesep,'*-0*']); %TODO: should enforce that this ends with a number?
  dataDirs=potentialDirs([potentialDirs.isdir]==true);

