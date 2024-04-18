function out=isWritable(filepath)
% check whether user has permisions to modify filepath
%
%    function out=isWritable(filepath)
%
% Purpose
% determines whether user has permisions to modify filepath
%
% Notes
% is Linux/Mac only. on Windows it just silently returns true
%
%
% Rob Campbell - Basel 2015


if ispc
    out=1;
    return
end




if ~exist(filepath)
    fprintf('%s: %s does not exist\n',mfilename,filepath)
    out=0;
    return
end

%escape dodgy characters, as these are non-escaped by default
filepath=regexprep(filepath, '[\s\(\)]', '\\$0');
[s,msg]=system(['touch ',filepath]);

if s ~= 1
    fprintf('Failed to check if file is writable:\n %s,\n', msg)
end

out=isempty(msg); %if touch works there is no message
