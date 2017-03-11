function warnLowDiskSpace(directory,percent)
% Issue warning with notify if disk space is running low
%
% function warnLowDiskSpace(directory,percent)
%
% 
% Purpose
% issue warning if device on which "directory" exists is more than "percent" full
%
%
% Inputs
% directory - string defining a directory. pwd if absent or empty
% percent - scalar between 1 and 99. If percent full is over this value we issue a 
%           notification with notify. 95 percent by default.
%
% Example
% warnLowDiskSpace('/mnt/data/rupert',80)
%  
%
%
% Rob Campbell - Basel 2015


if nargin<1 || isempty(directory)
    directory=pwd;
end

if nargin<2
    percent=95;
end


if ~exist(directory,'dir')
    fprintf('%s - directory %s does not exist\n',mfilename,directory);
    return
end

if percent>99 | percent<1
    fprintf('%s - percent is %d. Out of range. [1-99]\n',mfilename,percent)
    return
end


%Disp space used
spaceUsed=stitchit.tools.returnDiskSpace;



if spaceUsed.percentUsed>percent
    if isunix
        [~,hostname]=unix('hostname');
    else
        hostname=[];
    end
    msg=sprintf('Warning free space %s is LOW: %0.1f%%\n',['on ' ,hostname(1:end-1)],spaceUsed.percentUsed);
    stitchit.tools.notify(msg)
end


