function applyGIST2section_BATCH(chan,overwrite,nInstances)
% Conduct GIST seamless stitching on all TIFFs from a single channel directory
%
% function applyGIST2section_BATCH(chan,overwrite,nInstances)
%
% Purpose
% Remove seams from an already stitched images using a gradient-domain seam
% removal algorithm. For more information please do:
% help applyGIST2section
%
% Run from experimemt root directory. Corrected images are placed in a 
% new directory ending with "_GIST" Works only on full-size images. 
%
% Although the binaries wrapped by this function may be compiled for 
% all platforms, this batch script will only work on Mac and Linux because 
% it uses system-specific commands to look for processes that have stalled. 
%
%
% Inputs
% chan - channel to work on
% overwite is zero by default. If 1 we replace current files with GIST files. 
% nInstances - how many images to process at the same time. 5 by default. 
%              It is reasonable to crunch about 1 per system core. 
%
%
% Example
%  applyGIST2section_BATCH(2,0,5) 
%
% Rob Campbell - Basel 2015
%
% See also:
% applyGIST2section


if ~isunix
    error('This function requires Mac or Linux')
end

%Check that there are no processes hanging around from other runs
[s,uid] = unix('whoami');
uid=regexprep(uid,'\n','');

[s,msg] = unix(sprintf('ps x -U %s | grep -E ''Client.*--port '' ', uid));

%Remove empty lines and those are related to grep
msg = strsplit(msg,'\n');
for ii=length(msg):-1:1
    if isempty(msg{ii}) | findstr(msg{ii},'grep')
        msg(ii)=[]; 
    end
end

if ~isempty(msg)
    fprintf('There appear to be Client processes previously started by your user ID. Please kill these and try again:\n')
    for ii=1:length(msg)
        fprintf(msg{ii})
    end
    fprintf('\n')
    return
end


resize=100; %we will only work with the full size stack. 
userConfig=readStitchItINI;

sectionDir = sprintf('%s_%03d%s%d', ...
    userConfig.subdir.stitchedDirBaseName, ...
    resize,filesep,chan);


if ~exist(sectionDir,'dir')
    fprintf('directory %s does not exist\n',sectionDir)
    return
end



if nargin<2
    overwrite=0;
end

if nargin<3
    nInstances=5;
end

sections=handleSectionArg([]);


fnameLog = sprintf('GIST_LOG_%02d_%s.txt',chan,datestr(now, 'YYMMDD-hhmm'));

%Remove from the list sections that do not exist in the origina data directory
n=0;
for ii=size(sections,1):-1:1
    fname = sprintf('%s%ssection_%03d_%02d.tif',sectionDir,filesep,sections(ii,:));
    if ~exist(fname,'file')
        sections(ii,:)=[];
        n=n+1;
    end
    end
if n>0
    fprintf('***Skipping %d sections which were expected (based upon the Mosaic file) in the original stitched image directory but are missing\n',n)
end


if ~overwrite
    sectionDir = regexprep(sectionDir,filesep,['_GIST',filesep]);
    if ~exist(sectionDir,'dir')
        mkdir(sectionDir)
    end


    %Remove from the list sections that already exist in this directory
    n=0;
    for ii=size(sections,1):-1:1
        fname = sprintf('%s%ssection_%03d_%02d.tif',sectionDir,filesep,sections(ii,:));
        if exist(fname,'file')
            sections(ii,:)=[];
            n=n+1;
        end

    end
    if n>0
        fprintf('Skipping %d sections as these already exist in %s\n',n,sectionDir)
    end
end




%We run the analyses in parallel by starting the binary and running it in the background. 
%We don't use the parallel computing toolbox. We monitor the progress of the routines. 
%Killing those that have locked up and starting new ones as we're done. Deleting stuff
%that has already been created. 

numFinished=0; %The number of sections completed successfully 
numToDo=size(sections,1);
currentlyRunning={};
finished=0;
currentSection=0; %The index of the current section to add

killTimeThreshold=60*4; %If a process has existed for more than this number of seconds, we kill it.

if nInstances>numToDo
    nInstances=numToDo;
end

%report what we are about to do 
if numToDo==1
    logMessage(fnameLog,sprintf('Preparing to crunch %d section using %d parallel instances.\n',numToDo,nInstances))
elseif numToDo>1
    logMessage(fnameLog,sprintf('Preparing to crunch %d sections using %d parallel instances.\n',numToDo,nInstances))
elseif numToDo==0
    fprintf('No sections to crunch. Quitting\n')
    return
end



while ~finished
    
    %Start analyses by queuing file names and starting the client
    while size(currentlyRunning,1)<nInstances &  numFinished<numToDo & size(sections,1)>currentSection
        currentSection=currentSection+1;

        currentlyRunning{size(currentlyRunning,1)+1,1} = currentSection; %append to end
        thisInd=size(currentlyRunning,1);

        currentlyRunning{thisInd,2} = sections(currentSection,:); %add more info to the end

        msg=sprintf('\n\n=====>  %d/%d. Starting to analyse section %d/%d  <=====\n\n',...
            currentSection, size(sections,1), sections(currentSection,:));
        logMessage(fnameLog,msg)



        %Generate a unique temporary file name which will be the output of the GIST stitcher
           %This is necessary in case we're crunching another channel at the same time
           tmpName= sprintf('out_%d_%04d_%s.tif',currentSection,round(rand*1E4), datestr(now,'HHMMSS') );
        currentlyRunning{thisInd,6} = tmpName; %this is what we'll move to the final dir
        msg=sprintf('Corrected file will temporarily be stored in %s\n',currentlyRunning{thisInd,6});
        logMessage(fnameLog,msg)

           [~,~,tmpFnames]=applyGIST2section(currentlyRunning{thisInd,2},chan,currentlyRunning{thisInd,6},currentlyRunning{thisInd,1},1); %Begin crunching in background

        %Ensure we have a PID and a running client before carrying on. 
        thisPort = str2num(sprintf('1234%d',currentSection));
        fprintf('Looking for client on port %d\n',thisPort)
        PID = clientAtPort(thisPort);
        while PID==0
            fprintf('.')
            PID = clientAtPort(thisPort);
            pause(0.5)
        end
        
        logMessage(fnameLog,sprintf('\nClient started at port %d with PID %d\n',thisPort,PID));

        %Log the PID and start time for this section
        currentlyRunning{thisInd,3} = now;
        currentlyRunning{thisInd,4} = PID;
        currentlyRunning{thisInd,5} = thisPort;        

        %Log the file names
        currentlyRunning{thisInd,7} = tmpFnames; %we delete these temp files

           %Final file name
        fname = sprintf('%s%ssection_%03d_%02d.tif',sectionDir,filesep,sections(currentSection,:));
           fprintf('Planning to move %s to %s\n',tmpName,fname)

        currentlyRunning{thisInd,8} = fname; %we delete these temp files


        pause(3) %Pauses may help with stability, so let's add one here to ensure a little gap between each start of the Client
        
    end


    %At this point we have started crunching. We now want to monitor what's been started and kill
    %anything that has crashed so that it can be re-started. 
    for ii=size(currentlyRunning,1):-1:1
        %Monitor to see which have finished
        [RUNNING,pidMSG]=clientAtPort(currentlyRunning{ii,5});
        
        if RUNNING==0 %it has finished running

            %move the output file to its final resting place
            msg=sprintf('PID %d has completed in %d seconds. Moving %s to %s\n',...
                currentlyRunning{ii,5}, round((now-currentlyRunning{ii,3})*24*60^2), currentlyRunning{ii,6},currentlyRunning{ii,8});
            logMessage(fnameLog,msg)

            %TODO: figure out why this happens. It happens after a *different* section has failed. 
            if ~exist(currentlyRunning{ii,6})
                msg=sprintf('*** WARNING: corrected file %s is missing.\nAttempting to run again by appending section onto the end of the list.\n.',...
                    currentlyRunning{ii,6}, currentlyRunning{ii,2});
                logMessage(fnameLog,msg)
                sections(end+1,:) = sections(currentlyRunning{ii,1},:); %Copy current section to the end. Kinda horrible, but let's see how it goes. 

            else
                movefile(currentlyRunning{ii,6},currentlyRunning{ii,8})                
            end


            %Delete temporary files
            logMessage(fnameLog, sprintf('Deleting %s\n',currentlyRunning{ii,7}{1}))
            delete(currentlyRunning{ii,7}{1})

            logMessage(fnameLog, sprintf('Deleting %s\n',currentlyRunning{ii,7}{2}))
            delete(currentlyRunning{ii,7}{2})            

            logMessage(fnameLog, sprintf('\n%d is FINISHED. Removing from list.\n',currentlyRunning{ii,1}))
            currentlyRunning(ii,:)=[]; %clear this entry

            numFinished=numFinished+1;
            continue
        elseif isnan(RUNNING)
            msg=sprintf('Section %d/%d port: %s returned a NAN. Message was: %s\n', currentlyRunning{ii,2}, currentlyRunning{ii,5}, pidMSG);
            logMessage(fnameLog, msg)                
        end


        %Has this section stalled?
        delta = (now-currentlyRunning{ii,3})*24*60^2; %in seconds
        if delta>killTimeThreshold
            logMessage(fnameLog, sprintf('\n\n******** PID %d HAS STALLED!! ************\n\n\n',currentlyRunning{ii,4}));
            logMessage(fnameLog, sprintf('Failed stitched section is %d/%d\n',currentlyRunning{ii,2}));
            logMessage(fnameLog, sprintf('Temporary files are: %s and %s\n',currentlyRunning{ii,7}{:}))
            pause(1)


            hungPID = currentlyRunning{ii,4};
            [s,parentPID]=unix(sprintf('ps p %d o ppid=',hungPID));
            if s==0
                logMessage(fnameLog, sprintf('Parent PID is %s\n',parentPID));
            else
                logMessage(fnameLog, sprintf('Failed to find parent PID for %d\n', hungPID));
            end

            %Kill this process
            fprintf('Killing %d\n', hungPID)
            s=unix(['kill -9 ',num2str(hungPID)]);
            if s==0
                logMessage(fnameLog, sprintf('Killed %d successfully\n', hungPID))
            else
                logMessage(fnameLog, sprintf('Failed to kill %d \n',hungPID))
            end
            
            killParent=0;
            if killParent
                %Now kill the parent too 
                fprintf('Killing %s\n', parentPID)
                s=unix(['kill -9 ',parentPID]);
                if s==0
                    logMessage(fnameLog, sprintf('Killed parent PID %s successfully\n', parentPID))
                else
                    logMessage(fnameLog, sprintf('Failed to kill parent PID %d \n',parentPID))
                end
            end
            

            pause(2)

            %Restart this section
            logMessage(fnameLog,sprintf('Restarting the section\n'))
            logMessage(fnameLog, sprintf('Corrected file will temporarily be stored in %s\n',currentlyRunning{ii,6}))
            [~,~,tmpFnames]=applyGIST2section(currentlyRunning{ii,2},chan,currentlyRunning{ii,6},currentlyRunning{ii,1},1); %Begin crunching in background

        
            thisPort = str2num(sprintf('1234%d', currentlyRunning{ii,1}));
            fprintf('Looking for client on port %d',thisPort)
            PID = clientAtPort(thisPort);
            while PID==0
                fprintf('.')
                PID = clientAtPort(thisPort);
                pause(0.5)
            end

            logMessage(fnameLog, sprintf('\nClient started at port %d with PID %d\n Replacing original values with these\n',thisPort,PID));
            %Log the PID and start time for this section
            currentlyRunning{ii,3} = now;
            currentlyRunning{ii,4} = PID;
            currentlyRunning{ii,5} = thisPort;        
        end

        pause(2) %be a little nice
    end


    if numToDo==numFinished
        finished=1;
    end

end

logMessage(fnameLog,'**FINISHED**\n')


%print to screen and log to disk
function logMessage(fname,msg)

    fid=fopen(fname,'a+');
    fprintf(msg)
    msg=regexprep(msg,'^\n',''); %remove a single leading newline
    fprintf(fid,'%s: %s',  datestr(now,'HH:MM:SS'), msg);
    fclose(fid);