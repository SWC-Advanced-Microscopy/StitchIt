function stats=getShiftForSection(sectionNum, chan, maxTiles)
    % Get a bidi shift value for one section at a defined channel
    %
    % stats = stitchit.bidiCorrection.getShiftForSection(sectionNum, chan, maxTiles)
    %
    % Purpose
    % Get a bidi shift value for one section,
    %
    % Inputs
    % sectionNum - integer defining which section to analyse
    % chan - Which channel to use for the calculation. This input argument
    %        is required. You should choose the channel with the strongest
    %        signal. A purely auto-fluorescence channel is likely not
    %        going to have enough structure for this work.
    % maxTiles - optional, by default a maximum of 30 tiles are used.
    %
    %
    % Outputs
    % stats - structure with shift results for each tile.
    %
    %
    % Example
    % Get shifts for section 12 channel 2
    % >> stitchit.bidiCorrection.getShiftForSection(12,2)
    %
    % Rob Campbell - SWC 2019
    %
    % Also see:
    %  stitchit.bidiCorrection.getShiftsForChannel

    if nargin < 3
        maxTiles = 30;
    end

    T = tic;

    userConfig=readStitchItINI;

    param = readMetaData2Stitchit;
    rawDataDir = sprintf('%s%04d',directoryBaseName,sectionNum);


    preProcessPath = fullfile(userConfig.subdir.rawDataDir,userConfig.subdir.preProcessDir);
    preProcessPath = fullfile(preProcessPath,sprintf('%s%04d',directoryBaseName,sectionNum));
    preProcessPath = fullfile(preProcessPath,sprintf('tileStats_ch%.0f.mat', chan));
    if ~exist(preProcessPath,'file')
        stats=[];
        return
    end

    load(preProcessPath)




    mu = tileStats(1).mu{1};

    % If there are more than 25 tiles we get rid of the dimmest quarter
    [~,ind] = sort(mu,'descend');
    if length(mu)>25
        ind(round(length(ind)*0.25):end)=[];
    end


    % We might still have loads of tiles, though. If so we keep only a fixed number
    if length(ind)>maxTiles
        ind=ind(end-maxTiles+1:end);
    end

    % TODO -- check files exist before entering loop
    fprintf('\nStarting to get shifts for %d tiles of section %d\n', length(ind), sectionNum)
    for ii=1:length(ind)
        sectionTiff = sprintf('%s%04d_%05d.tif',directoryBaseName,sectionNum,ind(ii));
        pathToFile = fullfile(userConfig.subdir.rawDataDir, rawDataDir, sectionTiff);

        %The chan-1 is a horrible hack! TODO (why am I even doing this? [May 2023])
        [~,tmp]=stitchit.bidiCorrection.calibLinePhase(pathToFile,chan-1,true);
        tmp.sectionNumber=sectionNum;
        stats(ii) = tmp;
    end



    shiftvalues = [stats.shiftAmnt];
    shiftvalues(isnan(shiftvalues))=[];

    if ~isempty(shiftvalues)
        fprintf('Shift is %d\n',median(shiftvalues))
    else
        fprintf('No meaningful shifts calculated\n')
    end


    fprintf('getShiftForSection complete in %0.1f seconds\n', toc(T) );
