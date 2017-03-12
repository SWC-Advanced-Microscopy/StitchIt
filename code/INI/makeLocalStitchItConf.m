function makeLocalStitchItConf
% copy the default stitchitConf.ini to the current directory
%
% function makeLocalStitchItConf
%
% Inputs
% None
%
% Outputs
% None
%
% Rob Campbell - Basel 2014


fname = which('stitchitConf_DEFAULT.ini');

if ~exist(fname)
    error('Can not find %s',fname)
else
    copyfile(fname,'stitchitConf.ini')
end


