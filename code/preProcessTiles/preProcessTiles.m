function varargout=preProcessTiles(sectionsToProcess,combCorChans,illumChans,verbose)
% Load each tile and perform all calculations needed for subsequent quick stitching
%
% function analysesPerformed=preProcessTiles(sectionsToProcess,combCorChans,illumChans,verbose)
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
% INPUTS
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
% - combCorChans [optional] - zero by default. combCorChans can be a scalar or
%   a vector defining which image channels are to be *averaged together* for the 
%   comb correction. e.g. if it is [1,2], then we will average channels 1 and 2
%   and feed this into the comb correction algorithm. A single set of coefficients 
%   is produced for all channels. if zero or empty, no correction is done. 
% 
% - illumChans [optional] - zero by default. Same format as combCorChans, but 
%   we instead make an average image for each channel. This gives us greater 
%   flexibility down the road (e.g. average images from different
%   channels or not). If zero don't do illum correction.
%
% - verbose [optional] - 1 by default. If zero we supress messages indicating that 
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
% preProcessTiles([1,1;90,5],0,1)
%
% Two
% Process all illumination correction data not already done for channel 1.
% preProcessTiles([],0,1)
%
% Three
% re-precess everything for channel 1 illumination correction.
% preProcessTiles(-1,0,1)
%
%
%
% Notes
% If sectionsToProcess is zero, we skip tile stats creation if the tileStats file is present,
% we skip bidirectional scanning coefficient calculatuion if the first phaseStats.mat file is
% present. We skip average image calculation if the average images directory exists. i.e. if
% we processed one channel and want to now add another then we need to ask for the function to
% over-write. 
%
%
% Rob Campbell - Basel 2014


% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% Handle input arguments
if nargin<1 || isempty(sectionsToProcess)
    sectionsToProcess=0; 
end

if nargin<2 || isempty(combCorChans)
    combCorChans=0;
end

if nargin<3 || isempty(illumChans)
    illumChans=0;
end


%This is the output arg
analysesPerformed.combCor=0;
analysesPerformed.illumCor=0;

if ~illumChans & ~combCorChans
    fprintf('%s exiting with no analyses performed\n',mfilename)
    if nargout>0
        varargout{1}=analysesPerformed;
    end
    return
end

if nargin<4
    verbose=1;
end


%Load ini file variables
userConfig=readStitchItINI;

%tiles with averages smaller than lowValueThreshold will not contribute to the average image
lowValueThreshold = userConfig.analyse.lowValueThreshold; %TODO: we are no longer using this!


% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
%Find the raw directories we will descend into. 
paramFile=getTiledAcquisitionParamFile;
param=readMetaData2Stitchit(paramFile); 
baseName=directoryBaseName(paramFile);

if ~exist(userConfig.subdir.rawDataDir,'dir')
    error('%s can not find raw data directory: .%s%s',mfilename,filesep,userConfig.subdir.rawDataDir)
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

%Figure out which channels we are to load on each pass through the loop
illumChans=illumChans(:)'; %ensure it's a row vector
combCorChans=combCorChans(:)';
chansToLoad = unique([illumChans,combCorChans]);

%Loop through sections with a regular for loop and conduct
%analyses in parallel

for thisDir = 1:length(sectionDirectories)

    if isempty(sectionDirectories(thisDir).name)
        continue %Is only executed if user defined specific directories to process
    end



    %Skip if everything has been done and the user asked to loop through all directories.
    sectionDirName=fullfile(userConfig.subdir.rawDataDir,sectionDirectories(thisDir).name);
    statsFile=fullfile(sectionDirName,'tileStats');
    combFile=fullfile(sectionDirName,'phaseStats_01.mat');
    aveDir=fullfile(sectionDirName,'averages');

    %We skip if everything exists in the directory or if the non-existing files weren't ask for
    if ( exist(statsFile,'file') || exist([statsFile,'.mat'],'file') ) && ...
        (exist(combFile,'file') || (length(combCorChans)==1 && combCorChans==0)) &&...
        (exist(aveDir,'file')   || (length(illumChans)==1   && illumChans==0))   && ...
        length(sectionsToProcess)==1 && ...
        sectionsToProcess==0 
        if verbose
                fprintf('Nothing to do in %s. Skipping.\n', sectionDirectories(thisDir).name)
        end
        
        continue
    end


    %Load all layers and all channels in parallel 
    maxChans=3;
    imStack=cell(maxChans,param.mosaic.numOpticalPlanes);
    tileIndex=cell(maxChans,param.mosaic.numOpticalPlanes);

    %Extract section number from directory name
    sectionNumber = sectionDirName2sectionNum(sectionDirectories(thisDir).name);

    for thisChan = chansToLoad
        if thisChan==0
            continue
        end

        for thisLayer=1:param.mosaic.numOpticalPlanes
            fprintf('Loading section %03d, layer %02d, chan %d\n',sectionNumber,thisLayer,thisChan)
            %Load the raw tiles for this layer without cropping, illumination correction, or phase correction
            try 
                [thisImStack,thisTileIndex]=tileLoad([sectionNumber,thisLayer,0,0,thisChan],0,0,0); 
            catch
                fprintf('%s. Could not find images to load for channel %d. Is this channel missing?\n',mfilename, thisChan)
                analysesPerformed=[];
                break
            end
            imStack{thisChan,thisLayer}=thisImStack;
            tileIndex{thisChan,thisLayer}=thisTileIndex;
        end
    end


    %Bail out of this iteration if we couldn't load image data (likely due to missing tileIndex file)
    %the tileIndex file isn't created if generateTileIndex is confused about the number of raw TIFF files 
    %or if it can't find raw TIFF files
    if all(cellfun(@isempty,imStack))
        fprintf('%s couldn''t load any image data from directory %s. SKIPPING\n',...
            mfilename, sectionDirectories(thisDir).name)
        continue
    end


    %-----------------------------------------------------------------
    %Write tile statistics to a file. 
    if exist(statsFile,'file') & length(sectionsToProcess)==1 & sectionsToProcess==0 %Skip if sectionsToProcess is zero and file exists
        fprintf('%s stats file already exists\n',sectionDirectories(thisDir).name)
    else
        % Write tile statistics to disk. This can later be used to quickly calculate things like the intensity of
        % the backround tiles. 
        tileStats=writeTileStats(imStack, tileIndex, sectionDirName, statsFile);
    end

    %TODO be smarter in detecting if the following corrections are done. i.e. ALL the files should be present
    %-----------------------------------------------------------------
    %Do comb correction if user asked for it

    if combCorChans
        if length(sectionsToProcess)==1 && sectionsToProcess==0 && exist(combFile,'file')
            fprintf('%s exists. Skipping this comb corrrection\n',combFile)
        else    
            writeCombCorCoefs(imStack, sectionDirName, combCorChans)
            analysesPerformed.combCor=1;
        end
    end


    %-----------------------------------------------------------------
    %Do illumination correction if the user asked for it
    %Handle existing average files: wipe if necessary or load them in order to add to them. 
    if illumChans
        if length(sectionsToProcess)==1 && sectionsToProcess==0 && exist(aveDir,'dir')
            fprintf('Skipping illumination corrrection\n')
        else
            writeAverageFiles(imStack, tileIndex, sectionDirName, illumChans,tileStats.emptyTileThresh)
            analysesPerformed.illumCor=1;
        end
    end

end 


timeIt = toc;
if timeIt>180
    fprintf('Total time: %d minutes.\n',round(timeIt/60))
else
    fprintf('Total time: %d seconds.\n',round(timeIt))
end

if nargout>0
    varargout{1}=analysesPerformed;
end

