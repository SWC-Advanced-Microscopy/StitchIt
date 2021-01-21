function stats=getShiftForSection(sectionNum,chan)
    % Get all shifts from a section
    
    if nargin<2
        chan=2;
    end

    T = tic;

    userConfig=readStitchItINI;

    param = readMetaData2Stitchit;
    rawDataDir = sprintf('%s%04d',directoryBaseName,sectionNum);

    preProcessPath = fullfile(userConfig.subdir.rawDataDir,userConfig.subdir.preProcessDir);
    preProcessPath = fullfile(preProcessPath,sprintf('%s%04d',directoryBaseName,sectionNum));
    preProcessPath = fullfile(preProcessPath,sprintf('tileStats_ch%.0f.mat', chan));
    load(preProcessPath)




    mu = tileStats(1).mu{1};

    if length(mu)>25
        [~,ind] = sort(mu,'descend');
    end

    %ind(round(length(ind)/2):end)=[];
    ind(round(length(ind)*0.25):end)=[];

    % TODO -- check files exist before entering loop
    for ii=1:length(ind)
        sectionTiff = sprintf('%s%04d_%05d.tif',directoryBaseName,sectionNum,ind(ii));
        pathToFile = fullfile(userConfig.subdir.rawDataDir, rawDataDir, sectionTiff);
        fprintf('%s\n', pathToFile)
        
        [~,stats(ii)]=stitchit.bidiCorrection.calibLinePhase(pathToFile,chan-1,true); %The chan-1 is a horrible hack! TODO
    end



    shiftvalues = [stats.shiftAmnt];
    shiftvalues(isnan(shiftvalues))=[];

    if ~isempty(shiftvalues)
        fprintf('Shift is %d\n',median(shiftvalues))
    else
        fprintf('No meaningful shifts calculated\n')
    end


    fprintf('Function complete in %0.1f seconds\n', toc(T) );