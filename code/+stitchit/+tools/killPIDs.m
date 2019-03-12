function killPIDs(PIDs,simulate)
    % Kills a list of PIDs returned by findProcesses
    %
    % function killPIDs(PIDs,simulate)
    %
    % Purpose
    % Uses "kill -9" to executea a bunch of PIDs returned by findProcesses.
    %
    % Rob Campbell - SWC
    %
    % See also: findProcesses

    if nargin<2
        simulate=false;
    end

    if isempty(PIDs)
        fprintf('Found no PIDs to kill.\n')
    end

    for ii=1:length(PIDs)
        cmd = sprintf('kill -9 %s', PIDs{ii}{1});
        if ~simulate
            unix(cmd);
        else
            fprintf('SIMULATING: %s\n',cmd)
        end
    end
