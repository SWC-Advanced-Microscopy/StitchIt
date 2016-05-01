function [keys,ini]=stitchItINIkeys(INIfname)
% return a cell array of keys present in the in the StitchIt INI file
%
% function keys=stitchItINIkeys(INIfname)
%
% Purpose:
% The INI file called 'stitchitConf.ini' stores the stitching parameters. This
% function returns the keys as a cell array
%
% Inputs
% INIfname - [optional] if empty the string 'stitchitConf.ini' is used. 
%
%
% Outputs
% keys - a cell array of keys
% ini - INI file object
%
%
% Rob Campbell - Basel 2015
%
% requries IniConfig

if nargin<1
    INIfname='stitchitConf.ini';
end

if ~exist(INIfname,'file')
    fprintf('%s - can not find file %s. QUITTING!\n', mfilename, INIfname);
    return
end


%Read INI file
ini = IniConfig();
ini.ReadFile(INIfname);

sections = ini.GetSections;

keys={};
for ii=1:length(sections)
    keys = [keys;ini.GetKeys(sections{ii})];
end


