function logger(err,logFileName)
    % log error information to a file on disk
    %
    % function stitchit.tools.logger(err,logFileName)
    %
    %
    % Purpose
    % The logger function writes full error traces to disk during syncAndCrunch.
    % These full traces aren't sent to Slack or e-mail to avoid bloat. 
    %
    %
    % Inputs
    % err - the output of lasterror
    % logFileName - optional relative or absolute path to a file that will log the error messages. 
    %               If this is missing, we simply display the messages to screen. 
    %
    %
    % Rob Campbell - Basel 2016


    %Write error information to "logFileName"
    if nargin<2
        fid=1;
    elseif ischar(logFileName)
        fid=fopen(logFileName,'a+')
    else
        fid=1;
    end



    %Do not proceed if an error structure was not supplied
    if ~isstruct(err) || ~isfield(err,'identifier') || ~isfield(err,'message') || ~isfield(err,'stack')
        fprintf(fid,'\n%s -- ERROR: %s.m -- %s\n', datestr(now,'yy-mm-dd HH:MM:SS'), mfilename, 'can not log. First input not an error structure.');
        if nargin>1 && fid>1
            fclose(fid);
        end
        return
    end



    %Report error to disk or screen
    fprintf(fid,'\n%s -- ERROR: %s -- %s\n', datestr(now,'yy-mm-dd HH:MM:SS'), err.identifier, err.message);

    for ii=1:length(err.stack)
        tStack=err.stack(ii);
        fprintf(fid,' %s%s - %s - line %d\n', repmat(' ', ii,1),tStack.name, tStack.file, tStack.line);
    end



    if nargin>1 && fid>1
        fclose(fid);
    end
    