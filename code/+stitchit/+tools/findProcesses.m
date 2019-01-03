function PIDs=findProcesses(searchString)
    % Looks for process "searchString" and reports their PIDs
    %
    % function PIDs=findProcesses(searchString)
    %
    % Purpose
    % Looks for process "searchString" and reports their PIDs.
    % Also returns the information as a string.
    %
    % Rob Campbell - SWC
    %
    % See also: killPIDs

    cmd=sprintf('ps a | grep %s',searchString);
    fprintf('\nSearching for processes with: %s\n',cmd)
    [exitStatus, stdout]=unix(cmd);
    % Find the PIDs
    PIDs=regexp(stdout,' *(\d+) pts','tokens');
    if ~isempty(PIDs)
        fprintf('Found:\n%s\n',stdout)
    end
