function url = getGitHubPageURL(localDir)
% Return the Github URL of a local project
%
% function url = getGitHubPageURL(localDir)
%
% Inputs
% localDir - path to local git repo
%
% Outputs
% url - string to GitHub page. Returns empty if not a GitHub repo or 
% if it fails to get the remote name.
%
%
% Rob Campbell - Basel 2017

if ~stitchit.updateChecker.gitAvailable
    url='';
    return
end

[success,status] = system(sprintf('git -C %s remote show origin -n',localDir)); % -n suppresses remote query

if success~=0
    url=[];
    return
end

tok=regexp(status,'Fetch URL: (https:.*?)\.git','tokens');
if isempty(tok)
    url=[];
    return
else
    url = tok{1}{1};
end
