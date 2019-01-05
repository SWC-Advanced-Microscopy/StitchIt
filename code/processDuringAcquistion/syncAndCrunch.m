function syncAndCrunch(serverDir,chanToPlot,varargin)
% Pull data off acquisition system, pre-process, and send sample images to the WWW
%
% function syncAndCrunch(serverDir,chanToPlot, ... )
%
%
% Purpose
% Perform tile index generation, pre-processing of images, and send preview stitched
% images to the web. 
%
% Set up
% You should set up your INI file and define a landing directory before running this
% function. See also:
% https://github.com/BaselLaserMouse/StitchIt/wiki/Setting-up-syncAndCrunch
% https://github.com/BaselLaserMouse/StitchIt/wiki/syncAndCrunch-walk-through
% 
%
%
% Inputs
% If run with no input arguments, syncAndCrunch looks for a current
% acquisition on the acquisition system mount point and runs on
% this using the channel the user is currently viewing as that to
% send to the web. 
%
% serverDir - the full path to data directory on the server
% chanToPlot - Which channel to send to web (if missing, this is the first available 
%              channel). If zero, don't do the web plots. 
%
% Inputs (param/val pairs)
% landingDir - the full path to the local directory which will house the data directory. 
% illumChans - vector defining which channels will have mean images calculated.
%              If empty or missing, all available channels are corrected. To not calculate 
%              set to zero. These chans are stitched at the end.
% combCorChans - vector defining which channels will contribute to comb correction.
%               if empty or missing this is set to 0, so no correction is done. It is suggested
%               NOT to use this option unless you have TissueCyte data and you know what you 
%               are doing. Most users should never need this option.
%
%
% Example
% 1) Pull data from '/mnt/anatomyScope/sample01' into the default landing directory and
%    run illumination correction on all channels. Plot chan 2 to the web. 
%  >> syncAndCrunch('/mnt/anatomyScope/sample01',2)
%
% 2) Create the directory AE033 in /mnt/data/TissueCyte/AwesomeExperiments
% and sync data to it. Conduct comb-correction and illumination correction on chans 1:3
% then send channel 1 to the web.
%
% LDir = '/mnt/data/TissueCyte/AwesomeExperiments'
% SDir = '/mnt/tvbuffer/Data/AwesomeExperiments/AE033'
% syncAndCrunch(SDir,1,'landingDir',LDir,'illumChans',1:3,'combCorChans',1:3)
%
% 3) Just run "syncAndCrunch" (!)
%
%
% NOTE! 
% The string for the local landing directory arguments should NOT be:
% '/mnt/data/TissueCyte/AwesomeExperiments/AE033'
% It is: 
% '/mnt/data/TissueCyte/AwesomeExperiments/''
% However, syncAndCrunch will attempt to catch this error.
%
%
%
% Rob Campbell - Basel 2015, 2016, 2018
%                SWC 2019
%
    

if nargin==0
    ACQ=findCurrentlyRunningAcquisition;

    if isempty(ACQ)
    config=readStitchItINI; 
    MP = config.syncAndCrunch.acqMountPoint;
    fprintf('Can not find any currently running acquisitions at %s\n',MP)
    return
    end

    syncAndCrunch(ACQ.samplePath,ACQ.chanToDisplay);
    return
end
    
% Read the INI file  (Initial INI file read)
curDir=pwd;
try
    cd(serverDir)
    config=readStitchItINI; 

    if config.syncAndCrunch.landingDirectory == 0 
    fprintf(['\n\n ***\tPlease add the "landingDirectory" field to the syncAndCrunch section of your INI file.\n',...
        '\tSee the shipped default INI file in %s as an example\n\n'],  fileparts(which('readStitchItINI')) )
    return
    end

catch ME
    cd(curDir)
    rethrow(ME)
end

% Parse optional inputs
P=inputParser;
P.CaseSensitive=false;
P.addParamValue('landingDir', config.syncAndCrunch.landingDirectory)
P.addParamValue('illumChans',[]) %If empty all are processed, this is handled later
P.addParamValue('combCorChans',0)

P.parse(varargin{:});

landingDir=P.Results.landingDir;
illumChans=P.Results.illumChans;
combCorChans=P.Results.combCorChans;

if  ~ischar(landingDir) | landingDir==0
    fprintf('Please define a directory into which data will land.\n')
    return
end

if nargin<2 || isempty(chanToPlot)
    chanToPlot = illumChans(1);
end



%Input argument error checks
if ~exist(landingDir,'dir')
    fprintf('ERROR: Cannot find directory %s defined by landingDir\n',landingDir)
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
if strcmp(landingDir(end),filesep)
    landingDir(end)=[];
end
if strcmp(serverDir(end),filesep)
    serverDir(end)=[];
end

%Bail out of the two are the same
if strcmp(serverDir,landingDir)
    fprintf('ERROR: serverDir and landingDir are the same\n')
    return
end


if ~isnumeric(combCorChans)
    fprintf('ERROR: combCorChans should be a numeric scalar or vector\n')
    return
end

if ~isnumeric(illumChans)
    fprintf('ERROR: illumChans should be a numeric scalar or vector\n')
    return
end

if ~isempty(chanToPlot) && (~isnumeric(chanToPlot) || ~isscalar(chanToPlot))
    fprintf('ERROR: chanToPlot should be empty or a numeric scalar\n')
    return
end



%Report if StitchIt is not up to date
logFileName='StitchIt_Log.txt'; %This is the file to which error messages will be written
msg = sprintf(' --- Starting syncAndCrunch ---\n');
writeLineToLogFile(logFileName,msg);

try 
    stitchit.updateChecker.checkIfUpToDate;
catch ME
    stitchit.tools.logger(ME,logFileName)
    fprintf('Failed to check if StitchIt is up to date. Error written in %s\n',logFileName)
end
fprintf('\n\n')


% The experiment name is simply the last directory in the serverDir:
% TODO: is that really the best way of doing things? <--

%If local landing directory contains the experiment directory at the end, we should remove this and raise a warning
[~,expName,extension] = fileparts(serverDir);

[landingDirMinusExtension,localTargetRoot] = fileparts(landingDir);

if strcmp(localTargetRoot,expName)
    fprintf('\nNOTE: Stripping %s from landingDir. see help %s for details\n\n',expName,mfilename);
    landingDir = landingDirMinusExtension;
end

if ~isWritable(landingDir)
    msg = sprintf('WARNING: you appear not to have permissions to write to %s. syncAndCrunch may fail.\n',landingDir);
    writeLineToLogFile(logFileName,msg)
end


% expDir is the path to the local directory where we will be copying data
expDir = fullfile(landingDir,expName,extension); %we add extension just in case the user put a "." in the file name


% Attempt to kill any pre-existing syncer or rsync processes for this sample. 
% It's unlikely this will be the case, but just in case...
killSyncer(serverDir)

%Do an initial rsync 
% copy text files and the like into the experiment root directory
if ~exist(expDir,'dir')
    msg=sprintf('Making local raw data directory %s\n', expDir);
    writeLineToLogFile(logFileName,msg)
    mkdir(expDir)
end


% Copy meta-data files and so forth but no experiment data yet.
% We do this just to make the directory and ensure that all is working
exitStatus = unix(sprintf('rsync -r --exclude="/*/" %s%s %s', serverDir,filesep,expDir)); %copies everything not a directory
if exitStatus ~= 0
    msg=sprintf('Initial rsync failed. QUITTING\n');
    writeLineToLogFile(logFileName,msg)
    return
end

cd(expDir) %The directory where we are writing the experimental data

makeLocalStitchItConf %First make a local copy of the INI file. We need this for the background web image generation to work

% Only create the local "rawData" folder if it does not exist on the server. The TissueCyte will not make it
% but BakingTray does make it. 
if exist(fullfile(serverDir,config.subdir.rawDataDir),'dir')
    rawDataDir = expDir;
else
    rawDataDir = fullfile(expDir,config.subdir.rawDataDir);
end

msg=fprintf('STARTING!\nGetting first batch of data from server and copying to %s\n',rawDataDir);
writeLineToLogFile(logFileName,msg);

cmd=sprintf('rsync %s %s%s %s',config.syncAndCrunch.rsyncFlag, serverDir, filesep, rawDataDir);
msg = sprintf('Running:\n%s\n',cmd);
writeLineToLogFile(logFileName,msg)
unix(cmd);


% Now figure out which channels are available for illumination correction if the default (all available)
% is being used
if isempty(illumChans)
    illumChans = channelsAvailableForStitching;
    if isempty(illumChans)
    fprintf('ERROR: can not find any channels to work with.\n')
    return
    end
end
if isempty(chanToPlot)
    chanToPlot=illumChans(1);
end


if finished
    %If already finished when we start then we don't send Slack messages at the end. 
    expAlreadyFinished=true;
else
    expAlreadyFinished=false;
end



%% START SHELL SCRIPT TO PULL DATA OFF THE SERVER
tidyUp = onCleanup(@() SandC_cleanUpFunction(serverDir)); %First ensure we can tidy up in case of failure

pathToScript=fileparts(which(mfilename));
pathToScript=fullfile(pathToScript,'syncer.sh');

% TODO
% 1) Should this script use the "landing directory" or the full path to the local experiment directory?
%    I think I prefer the latter. It makes the script less flexible other uses but that's OK, I reckon. 
% 2) I was doing two rsyncs before in the while loop: one for raw data and one for files with extensions. 
%    Should I keep doing this?
%    [returnStatus,~]=unix(sprintf('rsync %s %s%s*.* %s', config.syncAndCrunch.rsyncFlag, serverDir,filesep, expDir)); %files with extensions copied to experiment dir
%    [returnStatus,~]=unix(sprintf('rsync %s %s%s %s', config.syncAndCrunch.rsyncFlag, serverDir, filesep, rawDataDir));
% 3) Test that the syncer will stop when a ctrl-c quits syncAndCrunch
unix(sprintf('%s -r %s -s %s -l %s &', ...
    pathToScript, ...
    config.syncAndCrunch.rsyncFlag, ...
    serverDir, ...
    fileparts(expDir)) ); %This is a hack to use the landing directory

% The shell script is now running in the background and we proceed with pre-processing
%%% - - - - - - - - - - - - - - - -  - - - - - - - - - - - - - - -  - - - - - - - -


% The raw data (section) directories are kept here
pathToRawData = fullfile(expDir,config.subdir.rawDataDir);

%Now enter a loop in which we alternate between pulling in data from the server and analysing
%those data
lastDir='';

sentPlotwarning=0; %To record if warning about plot failure was sent
sentConfigWarning=0; %Record if we failed to read INI file
sentCollateWarning=0;



% Start background web preview thread
if chanToPlot ~= 0
    startBackgroundWebPreview(chanToPlot,config)
end %if chanToPlot

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

    %read the StitchIt config file
    try
        config=readStitchItINI;
    catch ME
        if ~sentConfigWarning %Do not re-send using notify
            stitchit.tools.notify(sprintf('%s Failed to read INI file with error %s', generateMessage('negative'), ME.message))
            sentConfigWarning=1;
        else
            fprintf('Failed to read INI file with error %s\n', ME.message)
        end
        stitchit.tools.logger(ME,logFileName)
    end %try/catch



    %Bail out if the server directory is missing
    if ~exist(serverDir,'dir')
        msg=sprintf('Server directory %s missing. Quitting.', serverDir);
        fprintf([msg,'\n'])
        stitchit.tools.notify([generateMessage('negative'), ' ', msg]);
        return
    end


    %Pull data from acquisition system/server to local analysis machine
    params = readMetaData2Stitchit;
    numSections = params.mosaic.numSections;
    %Get the number of acquired directories so far
    numDirsAcquired = length(returnDataDirs(pathToRawData));


    %Do not proceed until we have at least one finished section
    dataDirs=returnDataDirs(pathToRawData);

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
        tifsInDir = dir(fullfile(pathToRawData,thisDir,'*.tif')); %tiffs in current dir
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
    catch ME
        stitchit.tools.notify(sprintf('%s Failed to generateTileIndex with:\n%s\n',...
            generateMessage('negative'), ME.message))
        stitchit.tools.logger(ME,logFileName)
    end %try/catch

    
    % - - - - 
    % Now call preProcessTiles to create average tiles, tile stats, etc
    fprintf('\nCRUNCHING newly found completed data directories with preProcessTiles\n\n')

    analysesPerformed = preProcessTiles(0,'combCorChans', combCorChans, ...
                                        'illumChans', illumChans); 
    fprintf('\nFINISHED THIS ROUND OF PROCESSING\n\n')
    % - - - - 


    if isempty(analysesPerformed)
        fprintf('Returning to start of loop: tile analysis failed!\n')
        pause(15)
        continue
    else
        fprintf('Assigning this as the last finished section\n')
        lastDir=thisDir; %The last directory to have been processed. 
    end

    %Don't collate average images after we have 15 sections of
    %them. For speed...
    if analysesPerformed.illumCor && sum(indexPresent)<15
        try
            collateAverageImages %GENERATE GRAND-AVERAGE IMAGES (although these keep getting over-written)
        catch ME
            if ~sentCollateWarning %So we don't send a flood of messages
                stitchit.tools.notify([generateMessage('negative'),' Failed to collate average images. ',ME.message])
                sentCollateWarning=1;
            else
                fprintf(['Failed to collate. ',ME.message]) 
            end
            stitchit.tools.logger(ME,logFileName)
        end %try/catch
    end %if analysesPerformed.illumCor


    % Check the background web preview is still running and re-start it if not. 
    fprintf('About to test whether web preview is running\n')
    if chanToPlot~=0 && ~exist('FINISHED','file')
        webPreviewLogLocation = '/tmp/webPreviewLogFile';
        fprintf('Testing whether web preview is still running\n')
        if ~exist(webPreviewLogLocation)
            msg=sprintf('No web preview log file at %s. Not making any web preview images.\n', webPreviewLogLocation);
            writeLineToLogFile(logFileName,msg);

        else

            T=dir(webPreviewLogLocation);
            secondsSinceLastUpdate = (now-T.datenum)*24*60^2;

            if secondsSinceLastUpdate > 60*2
                msg=sprintf('%d seconds elapsed since last update of web preview log file. RESTARTING WEB PREVIEW!\n', ...
                    round(secondsSinceLastUpdate));
                writeLineToLogFile(logFileName,msg);

                try 
                    startBackgroundWebPreview(chanToPlot,config)
                catch ME
                    if ~sentPlotwarning %So we don't send a flood of messages
                        stitchit.tools.notify([generateMessage('negative'),' Failed restart web preview. ',ME.message])
                        sentPlotwarning=1;
                    else
                        fprintf(['Failed to restart web preview. ', ME.message]);
                    end 
                    stitchit.tools.logger(ME,logFileName)
                end %try/catch
            else
              fprintf('Web preview log file last updated %d seconds ago\n',round(secondsSinceLastUpdate))
            end %secondsSinceLastUpdate

        end %if ~exist(webPreviewLogLocation
    else
      fprintf('Not testing for web preview. chan=%d\n', chanToPlot)
    end %if chanToPlot==0



    %Wait until the last section is completed before quitting
    if length(indexPresent)==(numSections+params.mosaic.sectionStartNum-1) && indexPresent(end) %Will fail if final section is missing a tile
        fprintf('\n** All sections have been acquired. Beginning to stitch **\n')
        unix('touch FINISHED');

        if ~all(indexPresent)
            unix('touch ORIG_DATA_HAD_MISSING_TILES');
        end
    elseif length(dir(fullfile(rawDataDir,'trigger','*.tr2'))) == numSections
       fprintf('\n** All sections have been acquired. Beginning to stitch **\n')
        unix('touch FINISHED');
        unix('touch ORIG_DATA_LIKELY_HAD_MISSING_TILES'); %Very likely contains missing tiles
    end %if length(indexPresent)
    

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
    stitchit.tools.warnLowDiskSpace(landingDir,90)
    msg = sprintf('Running post acquisition function\n');
    writeLineToLogFile(logFileName,msg);
    eval(postAcqFun) %Run the post-acquisition function
    success=true;
catch ME
    if ~expAlreadyFinished
        stitchit.tools.notify([generateMessage('negative'),' Stitching failed. ',ME.message])
        stitchit.tools.logger(ME,logFileName)
    end
    success=false;
end

if ~expAlreadyFinished && success
    msg=sprintf('Stitching finished!\n');
    writeLineToLogFile(logFileName,msg);
    stitchit.tools.notify(sprintf('%s %s has been stitched.',generateMessage('positive'),expName))
end

%Delete the web directory if it's there
if exist(config.subdir.WEBdir,'dir')
    success=rmdir(config.subdir.WEBdir,'s');
    if ~success
        msg = sprintf('Tried to delete directory %s but failed to do so\n',config.subdir.WEBdir);
        writeLineToLogFile(logFileName,msg);
    end
end


stitchit.tools.notify('syncAndCrunch finished')




%-------------------------------------------------------------------------------------
function out = finished
    % Return true if the finished file is present. false otherwise.
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
    % Return directories that are likely section directories based on the name
    potentialDirs=dir([rawDataDir,filesep,'*-0*']); %TODO: should enforce that this ends with a number?
    dataDirs=potentialDirs([potentialDirs.isdir]==true);


    function SandC_cleanUpFunction(serverDir)
    killSyncer(serverDir)
    msg = fprintf('Cleaning up syncAndCrunch\n');
    writeLineToLogFile('StitchIt_Log.txt', msg); %HARD-CODED


function startBackgroundWebPreview(chanToPlot,config)
    % Starts a background MATLAB process that sends low-res preview images of one channels to the web
    mPath = config.syncAndCrunch.MATLABpath;
    nSecRun = which('buildSectionRunner');

    % The script file name we will build to run the background task
    pathToBSfile = fullfile(tempdir,'webPreviewBootstrap.m');
    logFilePath = fullfile(tempdir,'webPreviewLogFile');
    
    % Before proceeding, let's kill any currently running background web previews
    PIDs=stitchit.tools.findProcesses(pathToBSfile);
    stitchit.tools.killPIDs(PIDs)

    % Write the boostrap file
    fid = fopen(pathToBSfile,'w');
    fprintf(fid,'cd(''%s'');\n', fileparts(nSecRun)); %cd to the function directory
    fprintf(fid,'buildSectionRunner(%d,''%s'');\n', chanToPlot, pwd);
    fclose(fid);

    if exist(mPath,'file')
        CMD = sprintf('%s -nosplash -nodesktop -r ''run("%s")'' > %s &', mPath, pathToBSfile, logFilePath);
        msg = sprintf('Running background web preview with:\n %s\n', CMD);
        writeLineToLogFile('StitchIt_Log.txt', msg); %HARD-CODED log file name, but ok...
        unix(CMD);
    else
        fprintf(['Can not find MATLAB executable at %s. ', ...
        'Not running background web preview process.\n'...
        'Web preview may lag behind acquisition if dataset is large.\n'], mPath)
    end


function writeLineToLogFile(logFileName,msg)
        % Simply writes a string to the log file and also displays on screen

        fprintf('%s',msg); %Display to screen

        fid=fopen(logFileName,'a+');
        if fid < 0
            fprintf('FAILED TO OPEN %s FOR WRITING\n', logFileName)
            return
        end

        fprintf(fid, '%s', datestr(now, 'HH:MM:SS dd-mm-yyyy - ') );
        fprintf(fid, '%s', msg);
        fclose(fid);

