function offsetValue = getOffset(coords, redo, offsetType,sectionSpecificOffset)
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
% For offsetType 'offsetDimmestGMM' we additionally save offset.offsetDimmestGMM_allSections,
% a raw (unsmoothed) per-section offset trace, since some detectors drift in background
% level over the course of an acquisition and the single pooled value above can then
% cause visible seams between sections. This is a self-describing struct with fields
% .sections (section numbers) and .values (raw offset per section). If tile.sectionSpecificOffset
% is enabled, getOffset returns a smoothed value from this trace for the requested section
% rather than the single pooled offset.
%
%
% INPUTS (required)
% coords - the coords argument from tileLoad
%
%
% INPUTS (optional)
% redo - if true, ignore offset file and overwrite it - default to false
% offsetType - by default provided by the stitchitIniFile. Valid values for this input
%            are: 'offsetDimmestGMM', 'averageTileMin', 'averageTileMean', 'scanimage'
% sectionSpecificOffset - true/false by default uses the value from the INI file.
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

if ~exist('redo', 'var') || isempty(redo)
    redo=false;
end

if ~exist('offsetType', 'var') || isempty(offsetType)
    offsetType = userConfig.tile.offsetType;
end

if ~exist('sectionSpecificOffset', 'var') || isempty(sectionSpecificOffset)
    sectionSpecificOffset = userConfig.tile.sectionSpecificOffset;
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

% A section-specific offset additionally needs the per-section trace ("_allSections")
% in the cache, so we can't be satisfied with the cache unless that is present too. Only
% offsetDimmestGMM produces such a trace. NOTE: during acquisition, periodic runs of
% collateAverageImages will flush old offset caches. So not needed here.
needAllSections = sectionSpecificOffset && strcmp(offsetType,'offsetDimmestGMM');

haveCache = ~redo && isfield(offset,offsetType) && ...
            (~needAllSections || isfield(offset,[offsetType,'_allSections']));

if ~haveCache
    if ~redo && ~isfield(offset,offsetType)
        fprintf('Recalculating offset: cached value requested but not found\n')
    end

    % Load the tile stats and calculate the offset
    tileStats = stitchit.tools.loadAllTileStatsFiles(chan);

    if isempty(tileStats)
        offsetValue=[];
        return
    end

    offset = calcOffset(offset, offsetType, coords, chan, tileStats, userConfig);
    save(offsetFileName, 'offset');
end

% Extract the value to return. By default this is the single pooled offset. If the user
% asked for a section-specific offset (and we have a per-section trace for this type)
% then instead return a smoothed, per-section value for this section (coords(1)).
offsetValue = offset.(offsetType);
if sectionSpecificOffset && isfield(offset,[offsetType,'_allSections'])
    offsetValue = sectionOffsetValue(offset.([offsetType,'_allSections']), coords(1), userConfig);
end

return



function offset = calcOffset(offset, offsetType, coords, chan, tileStats, userConfig)
% Calculate the requested offset type and add it to the offset structure

switch offsetType
    case 'offsetDimmestGMM'
        offset.(offsetType) = median([tileStats.offsetDimmestGMM]);
        % Also stash a raw, section-indexed offset trace (see rawPerSectionOffset below)
        offset.([offsetType,'_allSections']) = rawPerSectionOffset(tileStats, userConfig);


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



function rawOffset = rawPerSectionOffset(tileStats, userConfig)
    % Build a raw, section-labelled offset trace from the tileStats offsetDimmestGMM values.
    %
    % Some detectors drift in background level over the course of an acquisition, so a
    % single pooled offset can leave visible seams between sections once the true
    % background has moved on. Here we return one offset value per physical section: the
    % mean across imaged depths of offsetDimmestGMM. tileStats entries are matched onto
    % section directories by name (not array position), so a section with a missing
    % tileStats.mat file becomes a NaN that we then fill by linear interpolation, rather
    % than silently shifting every later section's value along by one. This is the RAW
    % trace: no smoothing is applied here, that comes later.
    %
    % The result is a struct with two parallel Nx1 fields so the trace is self-describing
    % (each value carries its section number) and lookups do not depend on reproducing the
    % directory order later:
    %   rawOffset.sections - the physical section number of each entry
    %   rawOffset.values   - the raw (unsmoothed) offset for that section

    % Canonical, ordered list of section directories (same glob as loadAllTileStatsFiles)
    baseName = directoryBaseName(getTiledAcquisitionParamFile);
    D = dir(fullfile(userConfig.subdir.rawDataDir,[baseName,'*']));
    sectionDirs = {D.name};

    % Last path component of each tileStats dirName, to match against sectionDirs
    tsDirNames = cellfun(@(p) regexp(p,'[^\\/]+$','match','once'), {tileStats.dirName}, 'UniformOutput', false);

    values = nan(length(sectionDirs),1);
    for ii = 1:length(sectionDirs)
        f = find(strcmp(tsDirNames, sectionDirs{ii}), 1);
        if ~isempty(f)
            values(ii) = mean(tileStats(f).offsetDimmestGMM);
        end
    end
    values = fillmissing(values, 'linear', 'EndValues', 'nearest');

    % Label each value with its section number so read-time lookups match by number
    rawOffset.sections = cellfun(@sectionDirName2sectionNum, sectionDirs(:));
    rawOffset.values = values;



function val = sectionOffsetValue(rawOffset, sectionNum, userConfig)
    % Return the smoothed, section-specific offset for one physical section.
    %
    % rawOffset is the raw, section-labelled trace from rawPerSectionOffset (fields
    % .sections and .values). We apply a running-average filter of width
    % userConfig.tile.sectionSpecificSmoothing sections to suppress the extra noise in
    % per-section estimates whilst still tracking slow detector drift, then return the
    % value for the requested section number. Lookup is by section number, so it is
    % robust to acquisitions that do not start at section 1.
    smoothOffset = movmean(rawOffset.values, userConfig.tile.sectionSpecificSmoothing);

    ind = find(rawOffset.sections==sectionNum, 1);
    if isempty(ind)
        % Section not found (shouldn't normally happen): fall back to the nearest one
        [~,ind] = min(abs(rawOffset.sections-sectionNum));
    end
    val = smoothOffset(ind);
