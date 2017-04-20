function out=estimateEndTimeBT
    % Estimate time left for a BT acquisition
    %
    % This is a temporary function 
    
    d=dir('acqLog_*.txt');


    out=[];
    if isempty(d)
        fprintf('Failed to find acq log.\n');
        return
    end

    if length(d)>1
        fprintf('Found more than one acq log. confused. quitting %s\n',mfilename);
        return
    end


    fid=fopen(d.name,'r');

    tline=fgetl(fid);

    finishedTimes=[];
    while 1
        tok=regexp(tline,' completed in (\d+) min (\d+) sec','tokens');
        if ~isempty(tok)
            m=str2num(tok{1}{1});
            s=str2num(tok{1}{2});
            finishedTimes(end+1)=(m*60)+s;
        end
        tline=fgetl(fid);

        if tline<0
            break
        end

    end

    fclose(fid);
    
    secondsPerDirectory = round(mean(finishedTimes));
    out.hoursPerDirectory=secondsPerDirectory/60^2;


    M=readMetaData2Stitchit;

    totalHours = out.hoursPerDirectory * M.mosaic.numSections;

    hoursLeft = totalHours - sum(finishedTimes)/60^2;

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




