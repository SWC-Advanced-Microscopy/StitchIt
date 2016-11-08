function systemType = determineStitchItSystemType
% allow StitchIt to determine the name of the acquisition system used for the current experiment
%
%	function systemType = determineStitchItSystemType
%
% 
% Outputs
% systemType - a string defining the name of the acquisition system used.
%              Currently returns one of 'TissueCyte' or 'BakingTray'
%

%Assign particular file names found in the experiment path to sub-directories in the SystemSpecifc directory
if ~isempty(dir('Mosaic_*.txt'))
	systemType='TissueCyte';
elseif ~isempty(dir('Recipe*.yml')) || ~isempty(dir('recipe*.yml'))
	systemType='BakingTray';
else
	fprintf('Can not find acquisition system log file in %s\n',pwd)
	systemType=-1;
end

