function iniData = readThisINI(fname)
% Read INI file defined by path fname and return as a structure
%
% function iniData = readThisINI(fname)
%
% Inputs
% fname - path to ini file
%
% Outputs
% iniData - ini file returned as a structure

out = IniConfig(fname);
iniData = out.returnAsStruct;
