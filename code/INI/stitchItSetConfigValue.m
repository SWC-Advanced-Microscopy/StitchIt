function stitchItSetConfigValue(key,value,INIfname)
% Change a value in the StitchIt INI file. Ensure we have a local copy before proceeding
%
% function stitchItSetConfigValue(key,value,INIfname)
%
% Purpose:
% Modify INI key in INI file in local directory. This is a helper function. 
% It's not used by StitchIt.
%
% Inputs
% key - the key to change.
% value - the value to which we set the key.
% INIfname - [optional] if empty the string 'stitchitConf.ini' is used. 
%
%
% Rob Campbell - Basel 2015
%
% requries IniConfig


if nargin<3
    INIfname='stitchitConf.ini';
end

if ~exist(INIfname,'file')
    fprintf('%s - can not find file %s. QUITTING!\n', mfilename, INIfname);
    return
end



%Determine where the ini file is located and refuse to move on if it's the master copy
INIfname = fullfile(pwd,INIfname);
if ~exist(INIfname,'file')
    fprintf('\nYou have no local INI file!\nPlease make a local copy then re-run this function. Value not changed!\n\n')
    return
end


%Find the key in the list.
[keys,ini]=stitchItINIkeys(INIfname);
index = strmatch(lower(key), lower(keys) );
if isempty(index)
    fprintf('Could not find key ''%s''.\nAvailable keys are:\n\n',key)
    disp(keys)
    return
end




%Find the section that contains the key
sections = ini.GetSections;
for ii=1:length(sections)
    f=strmatch(key,ini.GetKeys(sections{ii}));
    if ~isempty(f)
        break
    end
end



%Change the key
ini.SetValues(sections{ii}, key, value);
ini.WriteFile(INIfname);