function sectionNumber = sectionDirName2sectionNum(~,sectionDirName)
% For user documentation run "help sectionDirName2sectionNum" at the command line

tok=regexp(sectionDirName,'.*-(\d+)','tokens');

if isempty(tok)
    error('Unable to find section number from directory string')
end

sectionNumber = str2num(tok{1}{1});
