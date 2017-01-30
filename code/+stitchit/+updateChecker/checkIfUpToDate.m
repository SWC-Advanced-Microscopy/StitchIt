function [isUpToDate,status] = checkIfUpToDate(suppressMessages)
% Use Git to check if StitchIt is up to date
%
% [isUpToDate,status] = stitchit.updateChecker.checkIfUpToDate(suppressMessages)
%
%
% Purpose
% Use git to check if the StitchIt repo is up to date.
% Optionally returns true or false depending on the update state. 
% The results are printed to the screen. 
%
%
% Inputs
% suppressMessages - false by default
%
%
% Outputs:
% isUpToDate:   1  =  up to date
%               0  =  not up to date
%              -1  =  check failed
% status:   A string that reports what happened. e.g. if it failed then 
%           the status string reports why. 
%
%
% Rob Campbell - Basel 2017

if nargin<1
    suppressMessages=false;
end


if ~stitchit.updateChecker.gitAvailable
    isUpToDate = -1;
    status = 'No system Git is available';
    return
end




%First we do a fetch. This doesn't stop the user then doing a pull
dirToRepo=fileparts(which('stitcher'));
[success,status] = system(sprintf('git -C %s fetch',dirToRepo));
if success ~=0
    %Will return false for stuff like permissions errors
    isUpToDate=-1;
    return
end


%Now check if we're up to date
[success,status] = system(sprintf('git -C %s status -uno',dirToRepo));
if success ~=0
    isUpToDate=-1;
    return
end


if ~isempty(findstr(status,'Your branch is ahead')) ... 
    || ~isempty(findstr(status,'Changes not staged')) 
    isUpToDate = true;

    if ~suppressMessages
        fprintf('\n\n\t *** Note: your StitchIt install is up to date, but has local changes not present on the remote *** \n')
    end
end


if ~isempty(findstr(status,' have diverged'))    
    if ~suppressMessages
        fprintf('\n\n\t *** THE CODE IN YOUR StitchIt INSTALL HAS DIVERGED FROM THE REMOTE *** \n')
    end
    isUpToDate=-1;

elseif ~isempty(findstr(status,'Your branch is up-to-date'))
    isUpToDate = true;

elseif ~isempty(findstr(status,'Your branch is behind'))
    if ~suppressMessages
        clc
        n=84; %message character width

        gitURL=stitchit.updateChecker.getGitHubPageURL(dirToRepo);
        if ~isempty(gitURL);
            urlMessage=sprintf('\t*** Details at: %s',gitURL);
        else
            urlMessage='';            
        end

        lastUpdate = stitchit.updateChecker.getLastCommitTimeOfCurrentBranchOnRemote(dirToRepo);
        if ~isempty(lastUpdate)
            lastUpdate = sprintf('\t*** Latest update at: %s',lastUpdate);
        else
            lastUpdate='';
        end
            

        fprintf('\n\n\n\n\n\t%s\n',repmat('*',n,1))
        fprintf('\t***%s***\n',repmat(' ',n-6,1))

        fprintf('\t***%s - # WARNING # -%s*** \n',repmat(' ',(n/2)-11,1),repmat(' ',(n/2)-11,1)) 
        fprintf('\t*** Your StitchIt install IS NOT UP TO DATE. Please pull the latest version.%s*** \n',repmat(' ',n-79,1))
        if length(urlMessage)>0
            fprintf('%s%s***\n',urlMessage,repmat(' ',n-length(urlMessage)-2,1))
        end
        if length(lastUpdate)>0
            fprintf('%s%s***\n',lastUpdate,repmat(' ',n-length(lastUpdate)-2,1))
        end
        fprintf('\t***%s***\n',repmat(' ',n-6,1))
        fprintf('\t***%s***\n',repmat(' ',n-6,1))
        fprintf('\t%s\n\n\n',repmat('*',n,1))
    end

    isUpToDate=false;

else
    isUpToDate=-1;
    status = sprintf('UNABLE TO DETERMINE STATE OF REPOSITORY:\n %s', status);

end




