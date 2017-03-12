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
    fprintf('%s: % does not exist\n',mfilename,filepath)
    out=0;
    return
end

[s,msg]=system(['touch ',filepath]);
out=isempty(msg); %if touch works there is no message