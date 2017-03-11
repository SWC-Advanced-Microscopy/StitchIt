function varargout = returnDiskSpace(spaceInPath)
    % Returns a structure that lists the current disk space remaining 
    %
    % function diskSpace = returnDiskSpace(spaceInPath)
    %
    % Purpose
    % Lists the disk space remaining in GB for the volume in the current path
    % or, optionally, in the path defined by spaceInPath.
    %
    %
    % Inputs
    % spaceInPath - optional. Return space in this relative or absolute path.
    % 
    %
    % Outputs
    % diskSpace - a structure containing the fields 'freeGB', 'totalGB', and 'percentUsed'
    %
    %
    % Rob Campbell - Basel 2017

    if nargin<1
        spaceInPath=pwd;
    end

    % Convert 'C' into 'C:'
    if length(spaceInPath)==1 && ischar(spaceInPath) && regexp(spaceInPath,'[A-Z]')
        spaceInPath = [spaceInPath,':'];
    end

    if exist(spaceInPath,'file')
        % Because java.io.File might want a path instead of a file on some platforms
        spaceInPath = fileparts(spaceInPath);
    end

    %By nor it has to be a directory
    if ~exist(spaceInPath,'dir')
        fprintf('%s can not find path %s. QUITTING\n', mfilename, spaceInPath)
        return
    end


    results = java.io.File(spaceInPath);

    diskSpace.freeGB = results.getFreeSpace * 1024^-3;
    diskSpace.totalGB = results.getTotalSpace * 1024^-3;
    diskSpace.percentUsed = 100 - (diskSpace.freeGB / diskSpace.totalGB) * 100;


    if nargout>0
        varargout{1}=diskSpace;
    end
