function binRawData(sectionsToProcess, targetDir, binSize, binType, ...
    resolution, copySIHeader, copyBakingTrayFiles)
%BINRAWDATA Reads the raw data folder, bin tiff files and write
%them in targetDir
%
% binRawData(sectionsToProcess, targetDir, binSize, binType, ...
%            resolution, copySIHeader, copyBakingTrayFiles)
%
% Inputs:
% - sectionsToProcess: 0 for all, -1 to force redo, vector for list
% of sections
% - targetDir: path to save the data.
% - binSize: int or vector of int with bin size per dimension of
% tif file
% - binType: default mean. Str or cell array of string with ndims
% elements. How to group data in bin. Can be min, sum, max, mean.
% Is applied sequentially dimension per dimension.
% - resolution: Should the binning be done on double or native resolution?
% Output tiff will anyway be in native resolution
% - copySIHeader: default true. If true, the `Software` field of the first
% image of the original is copied with hRoiManager.linesPerFrame and 
% hRoiManager.pixelsPerLine updated to the binned value
% - copyBakingTrayFiles: default true. If true, copies the tilePosition.mat
% file from each section folder to the target dir


% Print warning and ask confirmation if binSize on Z
    if numel(binSize) > 2 && binSize(3) > 1
        fprintf(['WARNING: Raw data have channels interleaved. Do ' ...
                 'you really want to bin on third dimension\n'])
        answ = input('Y for yes, anything else cancels: ', 's');
        if ~strcmp(answ, 'Y')
            return
        end
    end
    
    if ~exist('binType', 'var') || isempty(binType)
        binType = 'mean';
    end
    if ~exist('resolution', 'var') || isempty(resolution)
        resolution = 'double';
    end
    if ~exist('copySIHeader', 'var') || isempty(copySIHeader)
        copySIHeader = true;
    end
    if ~exist('copyBakingTrayFiles', 'var') || isempty(copyBakingTrayFiles)
        copyBakingTrayFiles = true;
    end
    
    % Load ini file variables and parameters
    userConfig=readStitchItINI;
    paramFile = getTiledAcquisitionParamFile;
    param = readMetaData2Stitchit(paramFile);
    baseName = directoryBaseName(paramFile);

    % Find  list of directories to process
    if length(sectionsToProcess)==1 && sectionsToProcess<=0
        %Attempt to process all directories
        searchPath=[fullfile(userConfig.subdir.rawDataDir,baseName),'*'];
        sectionDirectories=dir(searchPath); %Create structure of directory names
        fprintf('\nFound %d raw data directories\n', length(sectionDirectories))
    elseif length(sectionsToProcess)>1 || sectionsToProcess(1)>0
        fprintf('Looping through a user-defined subset of directories\n')
        sectionDirectories=struct;
        for ii=1:length(sectionsToProcess)
            thisDirName=sprintf('%s%04d',baseName,sectionsToProcess(ii));
            if ~exist(fullfile(userConfig.subdir.rawDataDir, ...
                               thisDirName),'dir')
                continue
            end
            sectionDirectories(sectionsToProcess(ii)).name=thisDirName;
        end
    end
    
    if sectionsToProcess == -1
        overWrite = true;
    else
        overWrite = false;
    end

    if isempty(sectionDirectories) || ~isfield(sectionDirectories,'name')
        error(['%s can not find any raw data directories belonging to ' ...
               'sample %s'],mfilename,param.sample.ID)
    end
   

    % Create target directory
    if ~exist(targetDir, 'dir')
        mkdir(targetDir)
    end


    fprintf('\n')

    tStartProc = tic();
    % Main loop on section directories
    for thisDir = 1:length(sectionDirectories)
        if isempty(sectionDirectories(thisDir).name)
            continue %Is only executed if user defined specific directories to process
        end
        sectionDir = fullfile(userConfig.subdir.rawDataDir, ...
                              sectionDirectories(thisDir).name);
        
        % make a target dir for that section
        sectionTargetDir = fullfile(targetDir, ...
                                    sectionDirectories(thisDir).name);
        if ~exist(sectionTargetDir, 'dir')
            mkdir(sectionTargetDir)
        end
        fprintf('  doing %s\n', sectionDirectories(thisDir).name)
        binSectionFolder(sectionDir, param, sectionTargetDir, binSize, ...
                         binType, overWrite, resolution, copySIHeader);
        if copyBakingTrayFiles
            bktFiles = {'tilePositions.mat', 'COMPLETED', ...
                        'acquisition_log.txt'};
            for iF = 1:numel(bktFiles)
                fname = bktFiles{iF};
                tilePosPath = fullfile(sectionDir, ...
                                       fname);
                if ~exist(tilePosPath, 'file')
                    fprintf('No %s position file for %s\n', ...
                            fname, sectionDir)
                end
                tilePosTarget = fullfile(sectionTargetDir, fname);
                if sectionsToProcess < 0 || ~exist(tilePosTarget, 'file')
                    copyfile(tilePosPath, tilePosTarget);
                end
            end
        end
        
        tEndSec = toc(tStartProc);
        fprintf('  done section after %.2f s\n', tEndSec)
    end
    tEndProc = toc(tStartProc);
    fprintf('Done processing in %.2f s\n', tEndProc)
end

function binSectionFolder(sectionDir, param, targetDir, binSize, binType, ...
    overWrite, resolution, copySIHeader)
    % Subfunction called on every section folder

    tSecStart = tic;
    % Find tif files in the raw data folder
    numTiles = param.numTiles.X * param.numTiles.Y;
    sectionNumber = sectionDirName2sectionNum(sectionDir);
    ID = param.sample.ID;
    parfor iTile = 1:numTiles
        sectionTiff = sprintf('%s-%04d_%05d.tif', ID, ...
                              sectionNumber, iTile);
        fprintf('    doing %s\n', sectionTiff)
        path2stack = fullfile(sectionDir,sectionTiff);
        if ~exist(path2stack, 'file')
            fprintf('Cannot find raw data for %s. Skipping\n', ...
                    sectionTiff)
            continue
        end

        path2target = fullfile(targetDir, sectionTiff);
        if ~overWrite && exist(path2target, 'file')
            fprintf('%s already exists. Skipping\n', sectionTiff)
            continue
        end

        % Load the file
        data = stitchit.tools.loadTiffStack(path2stack, 'outputType', ...
                                            'int16');
        % Bin the data
%         toc(tSecStart);
        data = stitchit.tools.binNdArray(data, binSize, ...
                                                binType, 0, ...
                                         resolution);
        if ~strcmp(resolution, 'native')
            data = int16(data);
        end
        
        % Get scanimage metadata
        if copySIHeader
            imInfo = imfinfo(path2stack);
            soft = imInfo(1).Software;
            % replace the relevant part
            fields2rep = {'hRoiManager.linesPerFrame', 'hRoiManager.pixelsPerLine'}
            for iF = 1:2
                [~,~,c]=regexp(soft, [fields2rep{iF} ' = (\d+)']);
                c = c{1};
                newVal = num2str(size(data, iF));
                % extend with white spaces if new size has less digits
                while numel(newVal) < diff(c) + 1
                    newVal = [' ', newVal];
                end
                soft(c(1):c(2)) = newVal;
            end
        else
            soft = 'Matlab';
        end

        stitchit.tools.writeSignedTiff(data, path2target, soft)
    end
    tSecEnd = toc(tSecStart);
    fprintf('... in %.2 s\n', tSecEnd)
end
