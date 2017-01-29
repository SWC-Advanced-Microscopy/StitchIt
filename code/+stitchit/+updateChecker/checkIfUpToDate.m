function [isUpToDate,status] = checkIfUpToDate
% Use Git to check if StitchIt is up to date
%
% [isUpToDate,status] = stitchit.updateChecker.checkIfUpToDate
%
%
% Purpose
% Use git to check if the StitchIt repo is up to date.
% This command only runs if the repository is a clone
% of the original and not a fork. Optionally returns
% true or false depending on the update state. The
% results are printed to the screen. 
%
%
% Outputs:
% isUpToDate: 	1  =  up to date
%				0  =  not up to date
%		       -1  =  check failed
% status: 	A string that reports what happened. e.g. if it failed then 
%			the status string reports why. 
%
%
% Rob Campbell - Rob Campbell


if ~stitchit.updateChecker.gitAvailable
	isUpToDate = -1;
	status = 'No system Git is available';
	return
end

%Check if Git has the -C option
[success,stdout] = system(['git -C ',pwd]);
if findstr(stdout,'Unknown option')
	isUpToDate = -1;
	status = 'Git client has no -C option';
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

if ~isempty(findstr(status,'Your branch is ahead')) || ~isempty(findstr(status,'Changes not staged'))
	isUpToDate = true;
	fprintf('\n\n\t *** StitchIt is up to date, but has local changes not present on the remote *** \n\n')

elseif ~isempty(findstr(status,'Your branch is up-to-date'))
	isUpToDate = true;

elseif ~isempty(findstr(stdout,'Your branch is behind'))
	isUpToDate=false;

else
	isUpToDate=-1;
	status = sprintf('UNABLE TO DETERMINE STATE OF REPOSITORY:\n %s', status);

end

