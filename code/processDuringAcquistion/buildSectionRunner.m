function buildSectionRunner(chan,runInPath)
    % Simple function that constantly looks for new data and sends them to the web if found
    %
    % function buildSectionRunner(chan, runInPath)
    %
    % Purpose
    % Sends new data to the web when completed directories are found. 
    % Aborts when the FINISHED file appears. The channel to plot can be modified
    % once the function starts by editing the file at /tmp/buildSectionRunnerTargetChannel
    %
    % Inputs
    % chan - scalar defining which channel to plot to web
    % runInPath - used by syncAndCrunch to start this function in a background MATLAB
    %             process. In general use, this argument isn't needed. 
    %
    % Rob Campbell - SWC 2018 & 2019

    if nargin<2
      runInPath=pwd;
    end

    % This funtion may have been called from the system command line to run in the background from
    % syncAndCrunch using something like: via /usr/bin/MATLABR2017b/bin/matlab -nosplash -nodesktop -r 'run("buildSectionRunner(2)")'
    % In this case we must ensure that StitchIt is in the path. So we will test this first, and add it if needed, before carrying on. 
    thisMfile = which(mfilename);
    thisPath = fileparts(thisMfile);
    MATLABpath = path;

    if isempty(strfind(MATLABpath,thisPath))
        % buildSection runner is not in the path so neither is StitchIt.
        % Let's add StitchIt to the path
        fprintf('buildSectionRunner is at %s\n', thisMfile);
        StitchItPath = fileparts(thisPath);
        fprintf('Adding StitchIt to path at %s\n', StitchItPath);
        addpath(genpath(StitchItPath));
    end


    cd(runInPath) %Ensure we are in the correct path if the suer
                  %specified a different one
    fprintf('Running in directory: %s\n', runInPath);
    disp(datestr(now,'dd-mm-YYYY HH:MM:SS'))

    availableChannels = channelsAvailableForStitching;

    if nargin<1
        chan=availableChannels(1);
        fprintf('\n\n * No channel to plot defined.\n * Choosing channel %d to send to web\n\n', chan)
    end

    if isempty(find(availableChannels==chan))
        chan=availableChannels(1);
        fprintf('\n\n * Selected channel is not available.\n * Choosing channel %d to send to web\n\n', chan)
    end


    %Write this to a text file that will be read on each pass through the loop
    chanFname=fullfile(tempdir,'buildSectionRunnerTargetChannel');
    createTmpChanFile


    % This variable contains the channel we will attempt to plot on the
    % next pass through the main while loop (below). It can be modified
    % by editing the above text file as this file is read before each 
    % plotting attempt. The file is automatically fixed if does not 
    % contain a valid channel.
    chanToPlotNext = [];


    fprintf('%s is generating an initial tile index\n', mfilename)
    curN=generateTileIndex;


    fprintf(['%s will produce web previews of all new sections until the ' ...
             'FINISHED file appears\n'], mfilename)


    % Delete a lock file if it exists
    userConfig = readStitchItINI;
    lockfile=fullfile(userConfig.subdir.WEBdir,'LOCK');    
    if exist(userConfig.subdir.WEBdir,'dir') && exist(lockfile,'file')
      fprintf('%s deleting orphan lock file.\n', mfilename)
      delete(lockfile)
    end


    while ~exist('./FINISHED','file')
        t=generateTileIndex;
        if t~=curN
            curN=t;
            readChan % assigns the variable chanToPlotNext
            fprintf('%s calling buildSectionPreview with channel %d\n', ...
                    mfilename,chanToPlotNext)
            buildSectionPreview([],chanToPlotNext)
        end
        pause(10)
    end


    fprintf('Acquisition is FINISHED. %s is quitting\n', mfilename)
    delete(chanFname)

    function createTmpChanFile
        % Create a file that will contain the channel plot as originally defined
        % by the user at the command line. 

        fprintf('Writing channel to plot to file at %s\n', chanFname)
        try
            fid=fopen(chanFname,'w'); 
            fprintf(fid,'%d',chan); 
            fclose(fid);
        catch ME
          fprintf('Failed to create channel temp file with error:\n')
          disp(ME.message)
          return
        end
        fprintf('Finished writing channel to plot file\n')
        
          
    end %function createTmpChanFile

    function readChan
        % Read the channel to plot from the text file. If it's valid 
        % then assign it to a variable so it will be used on the next 
        % section. If it's not valid, replace it with the originally
        % chosen channel. 

        if ~exist(chanFname,'file')
           createTmpChanFile
        end

        try 
          fid=fopen(chanFname,'r');
          data=fscanf(fid,'%d');

          if length(data)>1
            disp('Channel file contains more than one number. Fixing it.')
            createTmpChanFile %replace with default
            chanToPlotNext = chan; %Use the default
            fclose(fid);
            return
          else
            fclose(fid);
          end

        catch ME
          fprintf('Reverting to channel %d\n', chan)
          disp(ME.message)
          createTmpChanFile %replace with default
          chanToPlotNext = chan; %Use the default
          return
        end
        

        if isempty(find(availableChannels==data))
            fprintf('Reverting to channel %d\n', chan)
            chanToPlotNext = chan; %Use the default
            createTmpChanFile % Replace file content
            return
        end

        %Otherwise we hope nothing went wrong and we use this channel to plot
        chanToPlotNext = data;
    end %function chan=readChan


end
