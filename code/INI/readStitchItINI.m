function [out,pathToINI]=readStitchItINI(varargin)
% Read SitchIt INI file into a structure
%
% function [out,pathToINI]=readStitchItINI(INIfname)
%
% Purpose:
% Parameters for StitchIt are stored in an INI file called 'stitchitConf.ini'
% This contains things like the number of microns per pixel (if the imaging system does not
% return this) and the stitching parameters your system needs (e.g. whether to crop the tiles). 
%
% readStitchItINI searches for the INI file in the following way:
% 1) If it is called from an experiment directory, it identifies the system ID using
%    readMetaData2Stitchit and attempts to load the system-specific INI file if this is
%    in the path. e.g. if M.System.ID is 'Noodle' then readStitchitINI looks for an 
%    INI file called stitchitConf_noodle.ini anywhere in the MATLAB path. Normal path rules 
%    apply: a file in the current directory takes precedence over one elsewhere.
%    Note we use lower case version in file name!
% 2) If a system-specific INI file is not found, readStitchitINI looks for a file called
%    stitchitConf.INI in the same way as it looked for the system-specific file
%
%
% Inputs
% All inputs as *optional* parameter/value pairs
% 'INIfname'   - Path to INI file to read. If empty or missing the above rules apply.
% 'systemType' = either 'TissueCyte' or anything else
%
% Outputs
% out - the contents of the INI file (plus some minor processing) as a structure
% pathToINI - path to the INI file.
%
% Example
%
% >> readStitchItINI; %Usually this is enough
% >> readStitchItINI('INIfname', '/opt/matlabCommon/stitchitConf_brainsaw.ini')
%
%
% Rob Campbell - Basel 2014


% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
%Parse optional arguments
params = inputParser;
params.CaseSensitive = false;
params.addParamValue('INIfname', []);
params.addParamValue('systemType', []);
params.parse(varargin{:});

INIfname=params.Results.INIfname;
systemType=params.Results.systemType;

% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

if isempty(INIfname)
    if isempty(systemType)
      systemType=determineStitchItSystemType;
    end
    
    if isnumeric(systemType) &&  systemType == -1
        INIfname='stitchitConf.ini'; %Try reading the default INI file
    else
        % This is really crap, but I need to read TissueCyte stuff in separately 
        % because we will get a recursive function call otherwise. TODO: fix this shit
        switch systemType
            case 'TissueCyte' 
                T=tissuecyte;
                M=T.readMosaicMetaData(T.getTiledAcquisitionParamFile);
                M.System.ID = M.ScannerID; %TODO: again, this should not be here. It's here because of the recursion problem. 
            case 'brainsaw'
                M.System.ID = 'brainsaw';
            otherwise
                M=readMetaData2Stitchit;
        end
 
        sysINIfname=sprintf('stitchitConf_%s.ini', lower(M.System.ID));
        localINIfname='stitchitConf_local.ini';
        defaultINIfname='stitchitConf.ini';
        if exist(fullfile(pwd,localINIfname),'file') 
          %First we ask if there is an ini file in the current directory
          INIfname = localINIfname;
        elseif exist(sysINIfname,'file')
          % Then the global one          
          INIfname = sysINIfname;
        elseif exist(defaultINIfname,'file')
          % Otherwise the defaults
          INIfname = defaultINIfname;
        else
           error(['Can not find any valid stitchit INI files. Not even a default one called %s.\n',...
            'Likely you have not set things up properly.'],defaultINIfname)
        end

    end
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
    %Reads TV objectives in by force TODO: fix this
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

%Pull out the current objective from the structure
% TODO: the following is system specific and very much tied to the TV.
% Need to get rid of it -- too complicated
if ~isfield(out, out.experiment.objectiveName)
    error('No objective name field %s found\nPlease check your INI file!', out.experiment.objectiveName')
end
thisObjective = out.(out.experiment.objectiveName);
%Note that for TV data sets, the number of microns per pixel is with respect to the 1664 image size
out.micsPerPixel.micsPerPixelMeasured=thisObjective.micsPerPixelMeasured;
out.micsPerPixel.micsPerPixelRows=thisObjective.micsPerPixelRows;
out.micsPerPixel.micsPerPixelCols=thisObjective.micsPerPixelCols;


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
