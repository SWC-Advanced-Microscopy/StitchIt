function sectionNumber = sectionDirName2sectionNum(sectionDirName)
% Get section number from the directory name containing raw data from that section
%
% function sectionNumber = sectionDirName2sectionNum(sectionDirName)
%
% PURPOSE
% Return the section number (numeric scalar) from the name of the directory
% containing raw data from that section.
%
% INPUTS
% sectionDirName - name of directory containing section data (string)
%
% OUTPUTS
% sectionNumber - numeric scalar that is the section number
%
%
% Rob Campbell - Basel 2016
tok=regexp(sectionDirName,'.*-(\d+)','tokens');

if isempty(tok)
    error('Unable to find section number from directory string')
end

sectionNumber = str2num(tok{1}{1});
