function branchName = getCurrentBranchName(localDir)
% Return the branch name of the Git repo at localDir
%
% function branchName = getCurrentBranchName(localDir)
%
% Inputs
% localDir - path to local git repo
%
% Outputs
% branchName - string defining the current branch name with the remote name. Returns 
% empty if it fails to get this for some reason.
%
%
% Rob Campbell - Basel 2017

if ~stitchit.updateChecker.gitAvailable
    branchName='';
    return
end

[success,status] = system(sprintf('git -C %s branch -vv --no-color',localDir)); 

if success~=0
    branchName=[];
    return
end

tok = regexp(status,'\* .* \[(\w+/\w+)\]','tokens');
if isempty(tok)
    branchName=[];
    return
end

branchName=tok{1}{1};