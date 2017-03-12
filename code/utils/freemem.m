function free=freemem
% Return the number of gigs of free RAM on Unix
%
%
% Purpose
% No "memory" function on Unix. This is a solution.
% Also attempts to work on Windows. 
%
% Rob Campbell - Basel 2015


if ispc %TODO: this isn't tested
    userMem = memory;
    memsize = user.MaxPossibleArrayBytes;
    free = memsize/1024^3; %convert to GB
    return
end

if isunix
    if ismac %TODO: get this working on the MAC
        fprintf('%s can not currently get free RAM on MAC\n',mfilename);
        return
    else
        [r,w] = unix('free | grep Mem')
        stats = str2double(regexp(w, '[0-9]*', 'match'));
        memsize = stats(1)/1e6;
        free = (stats(3)+stats(end))/1e6;
    end
end