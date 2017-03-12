function sectionNumber = sectionDirName2sectionNum(varargin)
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

%NOTE:
% This function instantiates an object specific to the data acquisition system being used
% then calls a method with the same name as this function. For implementation details see
% the SystemClasses directory. 
OBJECT=returnSystemSpecificClass;
sectionNumber = OBJECT.(mfilename)(varargin{:});
