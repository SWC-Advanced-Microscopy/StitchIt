function [sectionId,sectionDir] = lastCompletedSection
% return ID (index) and directory name of the last completed section
%
% function [sectionId,sectionDir] = lastCompletedSection
%
% Purpose
% Return last completed section ID and/or name to allow processing of data
% on the fly. This is done based on the trigger files. 
% This function is used by buildSectionPreview.
% 
% Note:
% The presence of the trigger file should indicate that all data are now present. 
% However, our production system recently (May 2015) started showing the trigger files
% without the last few tiles being present. These tiles eventually come through 
% (but slowly). Totally unclear why this is suddenly happening, but it means that the 
% presence of the trigger files isn't a sure-fire indication that all data are on the 
% sever. 
%
% Rob Campbell - Basel 2015

config=readStitchItINI;
triggerDir = [config.subdir.rawDataDir,filesep,'trigger'];

if ~exist(triggerDir,'dir')
	fprintf('No trigger directory found by %s. Exiting\n', mfilename);
	sectionId=[];
	sectionDir=[];
	return
end


trigFiles = dir([triggerDir,filesep,'*.tr2']);

if length(trigFiles)==0
	fprintf('No trigger files found by %s. Exiting/returning to caller\n', mfilename);
	sectionId=[];
	sectionDir=[];
	return
end


lastFile = trigFiles(end).name;

tok=regexp(lastFile,'.*-(\d+)\.tr2','tokens');
sectionId = str2num(tok{1}{1});

sectionDir = regexprep(lastFile,'\.tr2','');