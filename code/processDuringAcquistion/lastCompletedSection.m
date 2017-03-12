function sectionDir = lastCompletedSection
% return directory name of the last completed section
%
% function sectionDir = lastCompletedSection
%
% Purpose
% Return last completed section ID and/or name to allow processing of data
% on the fly. This is done based on the trigger files. 
% This function is used by buildSectionPreview.
% A "completed" section is one that is ready to be processed further. 
% Returns the last directory with a tileIndex file.
% 
%
% Rob Campbell - Basel 2015

config=readStitchItINI;
dataDirs = dir(fullfile(config.subdir.rawDataDir,[directoryBaseName,'*']));

if isempty(dataDirs)
    fprintf('No data directories found by %s. Exiting\n', mfilename);
    sectionDir=[];
    return
end

%Look backwards through dataDirs and return first directory which is completed
foundFinishedDir=0;
for ii=length(dataDirs):-1:1
    if exist(fullfile(config.subdir.rawDataDir,dataDirs(ii).name,'tileIndex'),'file');
        foundFinishedDir=1;
        break
    end
end

if ~foundFinishedDir
    fprintf('No completed directories found by %s. Exiting\n', mfilename);
    sectionDir=[];
    return
end

sectionDir=dataDirs(ii).name;
