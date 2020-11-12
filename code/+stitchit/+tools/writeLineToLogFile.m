function writeLineToLogFile(logFileName,msg)
    % Writes a string to the log file and also displays on screen
    %
    % Purpose
    % Used by syncAndCrunch to write to the log file. The string "msg"
    % is written to the file located at logFileName with a time and
    % date appended to the start
    %
    % Inputs
    % logFileName - name of the file to which to write. We will *append* 
    %               to this file only.
    % msg - string to be written

    fprintf('%s',msg); %Display to screen

    fid=fopen(logFileName,'a+');

    if fid < 0
        fprintf('FAILED TO OPEN %s FOR WRITING\n', logFileName)
        return
    end

    fprintf(fid, '%s', datestr(now, 'HH:MM:SS dd-mm-yyyy - ') );
    fprintf(fid, '%s', msg);
    fclose(fid);
