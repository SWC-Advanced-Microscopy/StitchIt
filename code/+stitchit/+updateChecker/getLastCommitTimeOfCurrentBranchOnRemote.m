function [timeAsString,status] = getLastCommitTimeOfCurrentBranchOnRemote(localDir)
% Return the last commit time of the current branch on the remote as a string based on Git repo at localDir
%
% function timeAsString = getLastCommitTimeOfCurrentBranchOnRemote(localDir)
%
% Inputs
% localDir - path to local git repo
%
% Outputs
% timeAsString - string defining the last commit time. Returns 
%                 empty if it fails to get this for some reason.
%
%
% Rob Campbell - Basel 2017


branchName = stitchit.updateChecker.getCurrentBranchName(localDir);
if isempty(branchName)
    timeAsString='';
    return
end



[success,status] = system(sprintf('git -C %s show --no-color --format="%%ci %%cr" %s ',localDir,branchName)); 

if success~=0
    timeAsString='';
    return
end


tok=regexp(status,'(20\d\d-\d\d-\d\d .* ago)','tokens');
if isempty(tok)
    timeAsString='';
end

timeAsString = tok{1}{1};
