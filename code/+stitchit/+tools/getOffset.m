function offsetValue = getOffset(coords, redo, offsetType)
% Get offset value for a channel
%
% function offsetValue = stitchit.tools.getOffset(coords, redo, offsetType)
%
% PURPOSE
% Load or calculate the image offset value from the average tiles. Offset values are
% cached channelwise in file called stitchitPreProcessingFiles/offset_chX.mat.
% Each file contains a structure with different channel offset types (averageTileMean, etc).
% These are calculated as needed. The file is deleted whenever collateAverageImages
% is run, ensuring it gets re-generated when the average images are modified. This is
% vital as small differences in the offset value can lead to large artifacts.
% Offsets are based on the pooled data (odd and even tiles).
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
% offsetValue - the offset (scalar) based on the requested offset type.
%               returns empty if no offset could be obtained.
%
%
% Example
% stitchit.tools.getOffset([1,1,0,0,2])


verbose=false; % Used internally for de-bugging


offsetValue = [];

%Load ini file variables and see if an offset file exists
userConfig=readStitchItINI;

if nargin<1
    fprintf('getOffset requires at least one input argument\n')
    return
end

if ~exist('chan', 'var') || isempty(chan)
    chan = 2;
end

if ~exist('redo', 'var') || isempty(redo)
    redo=false;
end

if ~exist('offsetType', 'var') || isempty(offsetType)
    offsetType = userConfig.tile.offsetType;
end

% Convenience variables
opticalPlane = coords(2);
chan=coords(5);

% Catch old offset names
if strcmp(offsetType,'offsetDimest')
    offsetType = 'offsetDimmestGMM';
end

if strcmp(offsetType,'averageMin')
    offset = 'averageTileMin';
end

% Valid values for the offset
validOffsetTypes = {'offsetDimmestGMM', ...
                    'averageTileMin', ...
                    'averageTileMean', ...
                    'scanimage'};

if isempty(strmatch(offsetType,validOffsetTypes,'exact'))
    fprintf('Function getOffset encounters invalid offset type: %s\n', offsetType)
    return
end



offsetFileName = fullfile(userConfig.subdir.rawDataDir, userConfig.subdir.preProcessDir, ...
    sprintf('offset_ch%.0f.mat', chan));

% Load if exists.
% The offset file is a structure with field names corresponding to valid values for the offset
% calculation. Thus, multiple offsets can be stored in one file and we have a log of what the
% offset actually was. For valid values see above.
if exist(offsetFileName,'file') && ~redo
    if verbose
        fprintf('Loading offset file %s\n', offsetFileName);
    end
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

if isempty(tileStats)
    offsetValue=[];
    return
end

switch offsetType
    case 'offsetDimmestGMM'
        offset.(offsetType) = median([tileStats.offsetDimmestGMM]);


    case 'averageTileMin'
        % Added for issue https://github.com/SWC-Advanced-Microscopy/StitchIt/issues/145
        aveTemplate = stitchit.tileload.loadBruteForceMeanAveFile(coords,userConfig);
        m=min(aveTemplate.pooledRows(:));
        if m>0
            m=0;
        end
        offset.(offsetType) = m;


    case 'averageTileMean'
        aveTemplate = stitchit.tileload.loadBruteForceMeanAveFile(coords,userConfig);
        m=mean(aveTemplate.pooledRows(:));
        if m>0
            m=0;
        end
        offset.(offsetType) = m;


    case 'scanimage'
        % Find the first image of that acquisition (not assuming that 1 is first)
        param=readMetaData2Stitchit;
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
        siOffset = single(firstSI.channelOffset);
        offset.(offsetType) = siOffset(chan);
end


save(offsetFileName, 'offset');

% get value to return
offsetValue = offset.(offsetType);


