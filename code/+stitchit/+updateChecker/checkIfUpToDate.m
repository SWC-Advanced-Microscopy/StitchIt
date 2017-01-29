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
[~,stdout] = system('git -C ');
if findstr(stdout,'Unknown option')
	isUpToDate = -1;
	status = 'Git client has no -C option';
	return
end


status=0;
isUpToDate=1;
dirToRepo=fileparts(which('stitcher'));
[status,stdout] = system(sprintf('git -C %s pull',dirToRepo))


%$ git fetch
%error: cannot open .git/FETCH_HEAD: Permission denied


%On branch master
%Your branch is ahead of 'origin/master' by 1 commit.
%  (use "git push" to publish your local commits)



 % git fetch

%  On branch master
%Your branch is behind 'origin/master' by 1 commit, and can be fast-forwarded.



