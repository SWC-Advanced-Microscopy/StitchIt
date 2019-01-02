function killSyncer(serverDir,simulate)
% Kill all syncer.sh processes associated with a defined server directory
%
% function killSyncer(serverDir,simulate)
%
% Purpose
% Used by syncAndCrunch to kill any running rsync or syncer instances
% if the user aborts syncAndCrunch before a FINISHED file was created. 
% The FINISHED file normally causes syncer.sh to stop. This function is 
% generally going to be called from syncAndCrunch and not by the user.
%
%
% Inputs
% serverDir - Full path to the directory on the server from which the 
%             data come. This is used to ensure we kill the correct
%             rsync processes.
% simulate - false by default. If true, nothing is killed but the
%            PIDs that would have been killed re reported to screen.
%
%
% Example
% killSyncer('/mnt/server/XYZ_123')
%
%
% Rob Campbell - July 2018, SWC


if nargin<2
    simulate=false;
end

if ~exist(serverDir,'dir')
    fprintf('%s fails to find directory %s\n', mfilename, serverDir)
    return
end

% Kill syncer.sh
% NB: Brackets avoid grep command appearing in ps results
searchString=sprintf('''[s]yncer\\.sh.* -s %s''',serverDir);
PIDs=stitchit.tools.findProcesses(searchString);
stitchit.tools.killPIDs(PIDs,simulate)


% Kill rsync
searchString=sprintf('''[r]sync .* %s ''',serverDir); 
PIDs=stitchit.tools.findProcesses(searchString);
stitchit.tools.killPIDs(PIDs,simulate)
