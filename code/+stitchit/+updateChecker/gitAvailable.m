function available = gitAvailable
% Returns true if git is available on the current system 
%
% available = stitchit.updateChecker.gitAvailable
%
%
% Rob Campbell


[success,stdout]=system('git --version');

if success==0
	available=true;
else
	available=false;
end


