function offsetValue = getOffset(coords, redo, offsetType)
% Get offset value for a channel
%
% function offsetValue = getOffset(chan)
%
% PURPOSE
% Load or calculate the offset. If the offset file already exists, load it.
% Otherwise, read all tileStats and take the median of the GMM fit to have
% a single offset per channel for the acquisition
%
%
% INPUTS (required)
% coords - the coords argument from tileLoad
%
%
% INPUTS (optional)
% redo - if true, ignore offset file and overwrite it - default to false
%
%
%
% OUTPUTS
% offsetValue - the offset (scalar) based on the requested offset type
%
%

offsetValue = [];
if nargin<1
    fprintf('getOffset requires at least on einput argument\n')
    return
end

if ~exist('chan', 'var') || isempty(chan)
    chan = 2;
end

if ~exist('redo', 'var') || isempty(redo)
    redo=false;
end

if ~exist('offsetType', 'var') || isempty(offsetType)
    offsetType = 'offsetDimest';
end


% Convenience variables
opticalPlane = coords(2);
chan=coords(5);


% Valid values for the offset
validOffsetTypes = {'offsetDimest', ...
                    'averageMin', ...
                    'scanimage'};

if isempty(strmatch(offsetType,validOffsetTypes,'exact'))
    fprintf('Function getOffset encounters invalid offset type: %s\n', offsetType)
    return
end



%Load ini file variables and see if an offset file exists
userConfig=readStitchItINI;

offsetFileName = fullfile(userConfig.subdir.rawDataDir, userConfig.subdir.preProcessDir, ...
    sprintf('offset_ch%.0f.mat', chan));

% Load if exists.
% The offset file is a structure with field names corresponding to valid values for the offset
% calculation. Thus, multiple offsets can be stored in one file and we have a log of what the
% offset actually was. For valid values see above.
if exist(offsetFileName,'file') && ~redo
    load(offsetFileName, 'offset');
else
    % If no file exists we start with an empty struct
    offset = struct;
end

if ~redo
    if isfield(offset,offsetType)
        offsetValue = offset.(offsetType);
        return
    else
        fprintf('Recalculating offset: cached value requested but not found\n')
    end
end


% If here then we need to save and calculate the offset.
tileStats = stitchit.tools.loadAllTileStatsFiles(chan);

switch offsetType
    case 'offsetDimest'
        offset.(offsetType) = median([tileStats.offsetDimest]);
    case 'averageMin'
        % This is a bit of hack. It was added to deal with issue
        % https://github.com/SainsburyWellcomeCentre/StitchIt/issues/145 and just stayed in
        aveTemplate = stitchit.tileLoad.loadBruteForceMeanAveFile(coords,userConfig);
        m=min(aveTemplate.pooledRows(:));
        if m>0
            m=0;
        end
    case 'scanimage'
            % Find the first image of that acquisition (not assuming that 1 is
    % first)
    dirNames = dir(userConfig.subdir.rawDataDir);
    dirNames = sort({dirNames.name});
    dirNames = dirNames(startsWith(dirNames, param.sample.ID));
    firstSlice = dirNames{1};
    firstSecNum = sectionDirName2sectionNum(firstSlice);
    % Get name of the first file, assuming the section starts at 1 (which should be true)
    firstSectionTiff = sprintf('%s-%04d_%05d.tif',param.sample.ID,firstSecNum,1);
    firstTiff = fullfile(userConfig.subdir.rawDataDir, firstSlice, firstSectionTiff);
    if ~exist(firstTiff, 'file')
        error('Asked for offset subtraction but could not load the first tiff of the acquisition:\n%s', firstTiff)
    end

    firstImInfo = imfinfo(firstTiff);
    firstSI=stitchit.tools.parse_si_header(firstImInfo(1),'Software'); % Parse the ScanImage TIFF header

end

save(offsetFileName, 'offset');


