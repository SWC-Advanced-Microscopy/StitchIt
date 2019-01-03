function makeLocalStitchItConf(useDefault)
% Copy the system default stitchitConf.ini to the current directory
%
% function makeLocalStitchItConf(useDefault)
%
% Purpose
% Copies the acquisition system default INI file to the local direcory 
% where it calls it "stichitConf.ini". Does not perform the copy if the 
% file already exists. 
% 
% Inputs
% useDefault - false by default. If true we copy the default INI file
%              which will be blank and need editing.
%
% Outputs
% None
%
% Rob Campbell - Basel, 2014
%                SWC, 2018


if nargin<1
    useDefault=false;
end

if useDefault
    pathToINI = which('stitchitConf_DEFAULT.ini');
else
    [~,pathToINI]=readStitchItINI;
end

if ~exist(pathToINI)
    error('Can not find %s',pathToINI)
else
    localFname=fullfile(pwd,'stitchitConf.ini');
    if exist(localFname,'file')
        fprintf('%s already exists. Not copying\n', localFname)
    else
        copyfile(pathToINI,localFname)
    end
end


