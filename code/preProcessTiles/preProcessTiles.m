function varargout=preProcessTiles(sectionsToProcess, varargin)
% Load each tile and perform all calculations needed for subsequent quick stitching
%
% function analysesPerformed=preProcessTiles(sectionsToProcess,combCorChans,'param1',val1, ...)
%
%
% PURPOSE
% For the final stitched image to look good we will need to pre-process the
% tiles before assembling. This precedes registration of the tiles. The
% following will need to be done by this function:
%  1) Calculate coefficients for fixing the comb-correction artifact. 
%  2) Calculate average images to remove vignetting, X-scanner turn-around brightening,
%     alternating light/dark lines, any weird bright spots caused by beam sitting 
%     stationary over the sample for some period of time. 
%  3) Store tile mean and median intensity for possible later use.
%
% The above are performed here. Each image is loaded only once in this phase. The 
% above steps will produce lots of coefficients. These will be stored in binary files 
% and .mat files located in each raw data directory. 
%
% The average image and comb-correction coefficients are calculated on the uncropped
% images so we can later change the cropping value and still produce sensible stitched
% data. The tile statistics (mean and median) are also performed on the uncropped data.
% Cropping has a small effect on statistics (about 2%), but is likely not important unless
% we use the statistics for a very exacting quantitative purpose (unlikely).
% 
%
%
% INPUTS (required)
% - sectionsToProcess - By default we loop through all of the section 
% directories and analyse the tiles they contain. However this can be modified:
% 1) If sectionsToProcess is zero (the default) or empty then conduct default
%    behavior: process all available directories and channels that don't contain 
%    processed data (see notes). 
% 2) If sectionsToProcess is -1, then we over-write all analysed data and we loop through
%    all available directories. This is the only way to start with a fresh average image
% 3) If sectionsToProcess is a vector or a scalar >0 then we analyse only these 
%    these section directories AND we over-write existing coefficient files in all 
%    channels.
%
%
% INPUTS (optional param/value pairs)
% - channelsToProcess - If is empty (default), all channels are
% used to  generate tileStats files. If 0, only channels from
% `combCorChans` and/or `illumChans` will be processed.
%
% - combCorChans - zero by default. combCorChans can be a scalar or
%   a vector defining which image channels are to be *averaged together* for the 
%   comb correction. e.g. if it is [1,2], then we will average channels 1 and 2
%   and feed this into the comb correction algorithm. A single set of coefficients 
%   is produced for all channels. if zero or empty, no correction is done. 
% 
% - illumChans - zero by default. Same format as combCorChans, but 
%   we instead make an average image for each channel. This gives us greater 
%   flexibility down the road (e.g. average images from different
%   channels or not). If zero don't do illum correction.
%
% - verbose - 1 (true) by default. If zero we supress messages indicating that 
%   analysis was skipped for a directory.
%
%
% OUTPUTS
% analysesPerformed - optionally return a structure of booleans that indicates which 
%                     analyses were performed at least once. (comb corr, illum corr)
%
%
% Examples
% One
% Process sections [1,1] and [90,5] (i.e. physical section 90, optical section 5)
% If these already exist, they are re-processed. Process only channel 1 illumination correction.
% preProcessTiles([1,1;90,5],0,'illumChans',1)
%
% Two
% Make tileStats only for physical sections 10 to 20 of channels 1 and 2
% preProcessTiles(1:20,1:2)
%
% Three
% Process all illumination correction data not already done for channel 1.
% preProcessTiles([],0,'illumChans',1)
%
% Four
% re-precess everything for channel 1 illumination correction.
% preProcessTiles(-1,0,'illumChans',1)
%
%
%
% Notes
% If sectionsToProcess is zero, we skip tile stats creation if the tileStats file is present,
% we skip bidirectional scanning coefficient calculation if the first phaseStats.mat file is
% present. We skip average image calculation if the average images directory exists. i.e. if
% we processed one channel and want to now add another then we need to ask for the function to
% over-write. 
%
%
% Rob Campbell - Basel 2014

% Constant
MAXCHANS=4; %number of the last possible channel

% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% Handle input arguments
if nargin<1 || isempty(sectionsToProcess)
    sectionsToProcess=0; 
end

params = inputParser;
params.CaseSensitive = false;
params.addParamValue('combCorChans', 0, @(x) isnumeric(x));
params.addParamValue('illumChans', 0, @(x) isnumeric(x));
params.addParamValue('channelsToProcess', 0, @(x) isnumeric(x));
params.addParamValue('verbose', true, @(x) islogical(x) || x==0 || x==1);
params.parse(varargin{:});

combCorChans=params.Results.combCorChans;
channelsToProcess=params.Results.channelsToProcess;
illumChans=params.Results.illumChans;
verbose=params.Results.verbose;


%This is the output arg
analysesPerformed.combCor=0;
analysesPerformed.illumCor=0;


%Load ini file variables
userConfig=readStitchItINI;

% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
%Find the raw directories we will descend into. 
paramFile=getTiledAcquisitionParamFile;
param=readMetaData2Stitchit(paramFile);
baseName=directoryBaseName(paramFile);

if ~exist(userConfig.subdir.rawDataDir,'dir')
    error('%s can not find raw data directory: .%s%s',mfilename,filesep,userConfig.subdir.rawDataDir)
end

%Create the directory into which we will save stitchit's parameters
stitchitParameterDir = fullfile(userConfig.subdir.rawDataDir, userConfig.subdir.preProcessDir);
if ~exist(stitchitParameterDir,'dir')
    mkdir(stitchitParameterDir)
end



if length(sectionsToProcess)==1 && sectionsToProcess<=0     %Attempt to process all directories
    searchPath=[fullfile(userConfig.subdir.rawDataDir,baseName),'*'];
    sectionDirectories=dir(searchPath); %Create structure of directory names
    fprintf('\nFound %d raw data directories\n', length(sectionDirectories))
elseif length(sectionsToProcess)>1 || sectionsToProcess(1)>0
    fprintf('Looping through a user-defined subset of directories\n')
    sectionDirectories=struct;
    for ii=1:length(sectionsToProcess)
        thisDirName=sprintf('%s%04d',baseName,sectionsToProcess(ii));
        if ~exist(fullfile(userConfig.subdir.rawDataDir,thisDirName),'dir'), continue, end
        sectionDirectories(sectionsToProcess(ii)).name=thisDirName;
    end
end


if isempty(sectionDirectories) || ~isfield(sectionDirectories,'name')
    error('%s can not find any raw data directories belonging to sample %s',mfilename,param.sample.ID)
end

fprintf('\n')

tic

%Figure out which channels we are to load on each pass through the
%loop
if isempty(channelsToProcess)
    channelsToProcess = [param.sample.activeChannels{:}];
end

illumChans=illumChans(:)'; %ensure it's a row vector
combCorChans=combCorChans(:)';
channelsToProcess=channelsToProcess(:)';
chansToLoad = unique([illumChans,combCorChans, channelsToProcess]);
% remove 0. The value for 'no channel' in combCorChans or illumChans
chansToLoad = chansToLoad(chansToLoad~=0);

%Loop through sections with a regular for loop and conduct
%analyses in parallel

for thisDir = 1:length(sectionDirectories)

    if isempty(sectionDirectories(thisDir).name)
        continue %Is only executed if user defined specific directories to process
    end

    % StitchIt will produce various statistics for stitching to proceed and will place these
    % in this directory: 
    sectionStatsDirName=fullfile(userConfig.subdir.rawDataDir, ...
        userConfig.subdir.preProcessDir, ...
        sectionDirectories(thisDir).name);

    if ~exist(sectionStatsDirName,'dir')
        mkdir(sectionStatsDirName)
    end

    % First create the needed tileStats
    % This step will write tile statistics to disk. This can later be used 
    % to quickly calculate things like the intensity of the backround 
    % tiles. If the offset subtraction was requested in the INI file (for 
    % non TV data) then we will apply this to the image stack. This is why 
    % we request the stack to be returned. 

    % Find what is written on disk and what need to be done
    if sectionsToProcess < 0 % if sectionsToProcess is -1, regenerate everything
        chanToStats = chansToLoad;
        statsToLoad = [];
    else
        chanToStats = [];
        statsToLoad = [];
        for iC = 1:numel(chansToLoad)
            chan = chansToLoad(iC);
            statsFile = fullfile(sectionStatsDirName, sprintf('tileStats_ch%.0f.mat', chan));
            if ~exist(statsFile, 'file')
                chanToStats(end+1) = chan;
            else
                statsToLoad(end+1) = chan;
            end
        end
    end

    % load data needed for tileStat creation
    [imStack, tileIndex, loadError] = load_imstack([], [], param, sectionDirectories(thisDir).name, chanToStats, MAXCHANS);
    if loadError
        if verbose
                fprintf('Error loading the data in directory %s. Skipping.\n', sectionDirectories(thisDir).name)
        end
        continue
    end

    % write statsFile for chans where it's needed
    tileStatsAllChan = cell([MAXCHANS, 1]);
    for chan = chanToStats
        statsFile = fullfile(sectionStatsDirName, sprintf('tileStats_ch%.0f.mat', chan));
        [tileStats,~] = writeTileStats(imStack(chan,:), tileIndex(chan,:), sectionStatsDirName, statsFile);
        tileStatsAllChan(chan) = {tileStats};
    end

    for chan = statsToLoad
        statsFile = fullfile(sectionStatsDirName, sprintf('tileStats_ch%.0f.mat', chan));
        onDisk = load(statsFile);
        tileStatsAllChan(chan) = {onDisk.tileStats};
    end

    if combCorChans
        % check if it's already done
        combFile=fullfile(sectionStatsDirName,'phaseStats_01.mat');
        if length(sectionsToProcess)==1 && sectionsToProcess==0 && exist(combFile,'file')
            fprintf('%s exists. Skipping this comb correction\n',combFile)
        else    
            % load channel if needed
            notLoaded = arrayfun(@(x) isempty(imStack{x,1}), combCorChans);
            [imStack, tileIndex, loadError] = load_imstack(imStack, tileIndex, param, ...
                sectionDirectories(thisDir).name, combCorChans(notLoaded), MAXCHANS);
            if loadError
                if verbose
                    fprintf('Error loading the data %s. Skipping.\n', sectionDirectories(thisDir).name)
                end
                continue
            end
            % perform comb cor
            writeCombCorCoefs(imStack, sectionStatsDirName, combCorChans)
            analysesPerformed.combCor=1;
        end
    end

    %Do illumination correction if the user asked for it
    %Handle existing average files: wipe if necessary or load them in order to add to them. 
    if illumChans
        aveDir=fullfile(sectionStatsDirName,'averages');
        chanDirs=arrayfun(@(x) fullfile(aveDir, num2str(x)), illumChans, 'un', 0);
        if length(sectionsToProcess)==1 && sectionsToProcess==0 && exist(aveDir,'dir') && ...
                all(cellfun(@exist, chanDirs))
            fprintf('Average folder already exists. Skipping illumination correction\n')
        else
            % load channel if needed
            notLoaded = arrayfun(@(x) isempty(imStack{x,1}), illumChans);
            [imStack, tileIndex, loadError] = load_imstack(imStack, tileIndex, param, ...
                sectionDirectories(thisDir).name, illumChans(notLoaded), MAXCHANS);
            if loadError
                if verbose
                    fprintf('Error loading the data %s. Skipping.\n', sectionDirectories(thisDir).name)
                end
                continue
            end
            % perform illum cor
            calcAverageMatFiles(imStack, tileIndex, sectionStatsDirName, illumChans, tileStatsAllChan)
            analysesPerformed.illumCor=1;
        end
    end

end %for thisDir = 1:length(sectionDirectories)



timeIt = toc;
if timeIt>180
    fprintf('Total time: %d minutes.\n',round(timeIt/60))
else
    fprintf('Total time: %d seconds.\n',round(timeIt))
end

if nargout>0
    varargout{1}=analysesPerformed;
end
end

function [imStack, tileIndex, loadError] = load_imstack(imStack, tileIndex, param, sectionDirectory, chansToLoad, maxChans)
% Function to load the channel and add them to imStack and tileIndex

    %Load all layers and all channels in parallel 
    if isempty(imStack)
        imStack=cell(maxChans,param.mosaic.numOpticalPlanes);
    end
    if isempty(tileIndex)
        tileIndex=cell(maxChans,param.mosaic.numOpticalPlanes);
    end

    %Extract section number from directory name
    sectionNumber = sectionDirName2sectionNum(sectionDirectory);
    loadError = 0;
    for thisChan = chansToLoad
        for thisLayer=1:param.mosaic.numOpticalPlanes
            fprintf('Loading section %03d, layer %02d, chan %d\n',sectionNumber,thisLayer,thisChan)
            %Load the raw tiles for this layer without cropping, illumination correction, or phase correction
            try 
                [thisImStack,thisTileIndex]=tileLoad([sectionNumber,thisLayer,0,0,thisChan], ...
                    'doIlluminationCorrection', false, ...
                    'doCrop', false, ...
                    'doCombCorrection', false, ...
                    'doSubtractOffset', false);
            catch ME
                fprintf('%s - Could not load images for channel %d. Is this channel missing?\n',mfilename, thisChan)
                fprintf('Failed with error message: %s\n', ME.message)
                loadError=1;
                break
            end
            if isempty(thisImStack)
                loadError=1;
            end
            imStack{thisChan,thisLayer}=thisImStack;
            tileIndex{thisChan,thisLayer}=thisTileIndex;
        end
    end
end
