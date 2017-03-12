function [running,msg] = clientAtPort(portNumber)
% function running = clientAtPort(portNumber)
%
% Purpose
% Returns the PID of the client process if GIST client is running at port portNumber
% Returns 0 otherwise. Only searches for Clients owned by the current user. 
%
% The port number should be the *full* port number (e.g. 123499)
% see applyGIST2section
%
% Rob Campbell - Basel 2015



if ~isunix
    error('This function requires Mac or Linux')
end

%Find all clients run by this user
[s,uid] = unix('whoami');
uid=regexprep(uid,'\n','');

[s,msg] = unix(sprintf('ps x -U %s | grep -E ''Client.*--port %d '' ', uid, portNumber));



%Remove empty lines and those are related to grep
msg = strsplit(msg,'\n');

for ii=length(msg):-1:1
    if isempty(msg{ii}) | findstr(msg{ii},'grep')
        msg(ii)=[]; 
    end
end


if isempty(msg)
    running=0;
    return 
end



%msg should have a length of 1 at this point and contain the PID
if length(msg)~=1
    fprintf('length msg does not equal 1:\n')
    for ii=1:length(msg)
        fprintf('\n%d: "%s"\n',ii,msg{ii});
    end
    error('multiple PIDs returned')
end


tok=regexp(msg{1},'^ *(\d+).*Client --pixels.*--labels','tokens'); 
if isempty(tok)
    fprintf('WARNING! Can not find PID in string "%s". Returning a NAN!\n',msg{1})
    msg=msg{1};
    running=nan;
else
    running=str2num(tok{1}{1});
end


