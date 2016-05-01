function [out,pathToINI]=readStitchItINI(INIfname,processIni)
% Read SitchIt INI file into a structure
%
% function [out,pathToINI]=readStitchItINI(INIfname,processIni)
%
% Purpose:
% The INI file called 'stitchitConf.ini' stores the stitching parameters. This
% function reads this file and returns it as a structure. 
%
% Inputs
% INIfname   - [optional] if empty or missing the string 'stitchitConf.ini' is used. 
% processIni - [optional] 1 by default. If 0 we don't do extra processing to calculate 
%              the number of microns per pixel, etc.
%
% Outputs
% out - the contents of the INI file (plus some minor processing) as a structure
% pathToINI - path to the INI file.
%
%
% Rob Campbell - Basel 2014


if nargin<1 | isempty(INIfname)
    INIfname='stitchitConf.ini';
end

if nargin<2
    processIni=1;
end


if ~exist(INIfname,'file')
    error('%s - can not find file %s.\n', mfilename, INIfname);
end


%Read INI file
out = readThisINI(INIfname);
pathToINI = which(INIfname); %So we optionally return the path to the INI file

%Load the default INI file
default = readThisINI('stitchitConf_DEFAULT.ini');


%Check that the user INI file contains all the keys that are in the default
fO=fields(out);
fD=fields(default);

for ii=1:length(fD)
    if isempty(strmatch(fD{ii},fO,'exact'))
        fprintf('Missing section %s in INI file %s. Using default values\n', fD{ii}, which(INIfname))
        out.(fD{ii}) = default.(fD{ii}) ;
        continue
    end



    %Warning: descends down only one layer
    sO = fields(out.(fD{ii}));
    sD = fields(default.(fD{ii}));
    for jj=1:length(sD)
        if isempty(strmatch(sD{jj},sO,'exact'))
           fprintf('Missing field %s in INI file %s. Using default value.\n',sD{jj}, which(INIfname))
           out.(fD{ii}).(sD{jj}) = default.(fD{ii}).(sD{jj});
        end
    end

end


if ~processIni
    return
end

%Pull out the current objective from the structure
if ~isfield(out, out.experiment.objectiveName)
    error('No objective name field %s found\nPlease check your INI file!', out.experiment.objectiveName')
end
thisObjective = out.(out.experiment.objectiveName);
out.micsPerPixel.micsPerPixelMeasured=thisObjective.micsPerPixelMeasured;
out.micsPerPixel.micsPerPixelRows=thisObjective.micsPerPixelRows;
out.micsPerPixel.micsPerPixelCols=thisObjective.micsPerPixelCols;


%Make sure the number of microns per pixel is correct. The values in the INI
%file are for 1664x1664 images. 
mosFname = getTiledAcquisitionParamFile(1);

if ~isempty(mosFname)
    param=readMetaData2Stitchit(mosFname);

    micsPerPixScaleFactor = out.micsPerPixel.numPix/param.tile.nRows; 
    out.micsPerPixel.micsPerPixelMeasured = out.micsPerPixel.micsPerPixelMeasured * micsPerPixScaleFactor;
    out.micsPerPixel.micsPerPixelRows = out.micsPerPixel.micsPerPixelRows * micsPerPixScaleFactor;
    out.micsPerPixel.micsPerPixelCols = out.micsPerPixel.micsPerPixelCols * micsPerPixScaleFactor;
else
    fprintf('%s: Not calculating mics per pixel -- no experiment directory found\n\n', mfilename)
end


function out=readThisINI(fname)
ini = IniConfig();
ini.ReadFile(fname);

sections = ini.GetSections;

for ii=1:length(sections)
    keys = ini.GetKeys(sections{ii});
    values = ini.GetValues(sections{ii}, keys);
    for jj=1:length(values)
        out.(sections{ii}(2:end-1)).(keys{jj})=values{jj};
    end
end
