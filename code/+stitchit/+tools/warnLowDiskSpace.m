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
% Notes 
% Linux only
%
% Rob Campbell - Basel 2015


if nargin<1
	directory=pwd;
end

if nargin<2
	percent=95;
end


if ~exist(directory,'dir')
	fprintf('%s - %s does not exist\n',mfilename,directory);
	return
end

if percent>99 | percent<1
	fprintf('%s - percent is %d. Out of range. [1-99]\n',mfilename,percent)
	return
end



[returnVal,stdout] = unix(['df ',directory]);
if returnVal ~=0
	fprintf('%s - df command failed\n',mfilename)
	return
end


%Get percent full
tok=regexp(stdout,'(\d+)%','tokens');
if isempty(tok)
	fprintf('%s - failed to find percent full\n',mfilename)
	return
end
percentFull = str2num(tok{1}{1});


%get mount point
tok=regexp(stdout,'\d+% (.*\w)','tokens');
mountPoint = tok{1}{1};




if percentFull>percent
	[~,hostname]=unix('hostname');
    msg=sprintf('Warning free space on %s %s is at %d%%\n',hostname(1:end-1),mountPoint,percentFull)
	stitchit.tools.notify(msg)
end


