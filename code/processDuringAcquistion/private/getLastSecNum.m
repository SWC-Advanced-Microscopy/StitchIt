function lastSecNum = getLastSecNum
% return the index of the last section directory on disk
%
% function lastSecNum = getLastSecNum
%
% Purpose
%Figure out the current section number for this series. However, we can't just use
%the number from the directory file name since this will be wrong if we asked for the 
%numbering to start >1. Thus we have to calculate the current section number. Doing it 
%this way is more robust than counting the number of directories minus 1 since it's
%conceivable someone could delete directories during the acquisition routine. This way
%it only matters what the first directory is.
%
% Inputs
% Index fo current sect


userConfig = readStitchItINI;


tok=regexp(lastCompletedSection,'(.*)-(.*)','tokens');
sample=tok{1}{1};
thisSecNum = str2num(tok{1}{2});



d=dir([userConfig.subdir.rawDataDir,filesep,directoryBaseName,'*']);
if ~isempty(d)
   tok=regexp(d(1).name,'(.*)-(.*)','tokens');
   firstSecNum = str2num(tok{1}{2});
   lastSecNum = thisSecNum - firstSecNum + 1;
else
  lastSecNum = 0;
  fprintf('Can not find section number.\n')
end
