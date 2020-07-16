function varargout=estimateEndTime
% Estimates time at which the current imaging run will end
%
% function endTime=estimateEndTime
%
% PURPOSE
% Estimate time at which the current imaging run will end. Initially uses the 
% number of tiles, etc, to figure this out. Once 5 sections have been taken,
% it uses the interval between sections instead. 
%
% Rob Campbell - Basel 2015


    % Find the acquisition log file
    d=dir('acqLog_*.txt');

    verbose=false;
    if verbose
      fprintf('\n%s verbose mode set to TRUE\n', mfilename)
    end
    
    out=[];
    if isempty(d)
        fprintf('Failed to find acq log.\n');
        return
    end

    if length(d)>1
        fprintf('Found more than one acq log. confused. quitting %s\n',mfilename);
        return
    end

    
    % Open the acq log file and read it in line by line
    fid=fopen(d.name,'r');

    tline=fgetl(fid);

    finishedTimes=[];
    while 1
        % Extract lines that contain section completion time
        % information. The following regex copes with the scenario
        % where the "secs" is missing.        
        tok=regexp(tline,' completed in (\d+) mins? *(\d+)?(?: secs)?','tokens');
        if ~isempty(tok)
            m=str2num(tok{1}{1});
            s=str2num(tok{1}{2});
            if isempty(s)
              s=0;
            end
            
            finishedTimes(end+1)=(m*60)+s;
        end
        tline=fgetl(fid);

        if tline<0
            break
        end

    end
    fclose(fid);


    % Process this information
    secondsPerDirectory = round(mean(finishedTimes));
    out.hoursPerDirectory=secondsPerDirectory/60^2;
    if verbose
      fprintf('On average %d seconds per directory (%0.3f hours)\n', ...
              round(secondsPerDirectory), out.hoursPerDirectory)
    end

    
    M=readMetaData2Stitchit;
    totalHours = out.hoursPerDirectory * M.mosaic.numSections;
    if verbose
      fprintf('Acquisition consists of %d sections, which will take a total of %0.1f hours.\n', ...
              M.mosaic.numSections, totalHours)
    end

    hoursLeft = totalHours - sum(finishedTimes)/60^2;
    
    if verbose
      fprintf('There are %0.2f hours left\n', hoursLeft)
    end
    


    % Fail gracefully if something went wrong earlier
    if isnan(hoursLeft)
        out.finishingString = 'estimateEndTimeBT failed to calculate end time';
        return
    end

    % Otherwise build a nice string
    if hoursLeft<1
        out.finishingString='FINISHING SOON';
    else
        out.finishingString=sprintf('Finishing at %s', datestr(now+hoursLeft/24, 'HH:MM on ddd dd/mm'));
    end


    if hoursLeft > 1.5
        out.remainingString=sprintf('Time left: %d hours', round(hoursLeft));
    else
        out.remainingString=sprintf('Time left: %d minutes', round(hoursLeft*60));
    end
