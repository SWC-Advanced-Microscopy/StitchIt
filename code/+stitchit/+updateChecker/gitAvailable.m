function available = gitAvailable
% Returns true if git is available on the current system and has the -C option
%
% available = stitchit.updateChecker.gitAvailable
%
%
% Rob Campbell


[success,stdout]=system('git --version');

if success==0
    %Check if Git has the -C option
    [success,stdout] = system(['git -C ',pwd]);
    if findstr(stdout,'Unknown option')
        isUpToDate = -1;
        status = 'Git client has no -C option';
    else
        available=true;
        return
    end
end


available=false;

