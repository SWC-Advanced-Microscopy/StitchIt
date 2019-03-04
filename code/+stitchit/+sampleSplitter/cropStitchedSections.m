function cropStitchedSections(ROIs)
% Make cropped stitched image series with one or more ROIs
%
% cropStitchedSections(ROIs)


s=findStitchedData;


[okToRun,diskStats]=stitchit.sampleSplitter.checkDiskUsage(ROIs,s);
if ~okToRun
    fprintf(['Cropped stacks will temporarily need %0.1f GB.\n',...
        'Since only %0.1f GB is free we do not proceed\n'], ...
        diskStats.totalDiskUsageOfCroppedStackInGB, diskStats.diskUsage.freeGB)
    return
end

uncroppedDir = ['UncroppedStacks_', datestr(now,'yymmdd_HHMM'),'_DELETE_ME_DELETE_ME']; %things we crop successfully go here
atLeastOneWorked=false; % True if at least one of the full size image stacks cropped successfully

% There are multiple ROIs we assume there are multiple samples so set it up as such
if length(ROIs)
    for ii=1:length(ROIs)
        mkdir(ROIs(ii).name)
    end
end


for ii=1:length(s)
    % This loop is in case the user has made a downsampled image series. We will crop all of them
    fprintf('Cropping directory %s\n', s(ii).stitchedBaseDir);

    % If this is the case we will be cropping the stack and not making a new sample directory
    if length(ROIs)==1
        cropDirName{1}=['CROP_',s(ii).stitchedBaseDir];
        mkdir(cropDirName{1})
    else
        % Multiple samples: make a stitched directory within each sub-directory
        for kk=1:length(ROIs)
        cropDirName{kk}=fullfile(ROIs(kk).name ,s(ii).stitchedBaseDir);
        mkdir(cropDirName{kk})
    end

    for jj=1:length(s(ii).channel)
        fprintf('Cropping channel %d\n', s(ii).channelsPresent(jj));


        for kk=1:length(cropDirName)
            %Make channel directory
            chanTargetDir{kk} = fullfile(cropDirName{kk}, num2str(s(ii).channelsPresent(jj)));
            mkdir(chanTargetDir{kk})
        end

        runCrop(s(ii).channel(jj), ROIs, s(ii).micsPerPixel, chanTargetDir) %This is where the work is done
    end


    allOK = stitchit.sampleSplitter.checkROIapplication(s(ii), cropDirName);
    if allOK
        atLeastOneWorked=true;
        % Move the original stitched data to the cropped directory
        movefile(s(ii).stitchedBaseDir, uncroppedDir);

        %If necessary, copy meta-data to new sample directories
        if length(ROIs)>1
            for ii=1:length(ROIs)
                %Following copy operation is somewhat hard-coded, but should encompass enough
                %stuff to work well even we change things around a bit,
                cellfun(@(x) copyfile(x,cropDirName{kk}), {'*.yml','*.txt','*.mat','*.ini'})
            end
        end
    end

end % ii=1:length(s)


if atLeastOneWorked
    movefile('downsampledMHD*',uncroppedDir)
    downsampleAllChannels %re-build the downsampled stacks
end





%--------------------------------------------------------------------------------
function runCrop(fileList, ROIs, micsPix, chanTargetDir)


    parfor ii = 1:length(fileList.tifNames)
        % Load the image
        fname = fullfile(fileList.fullPath, fileList.tifNames{ii});
        imToCrop =  stitchit.tools.openTiff(fname);

        croppedImage=stitchit.sampleSplitter.getROIfromImage(imToCrop,micsPix, ROIs);
        for ii=1:length(croppedImage)
            imwrite(croppedImage{ii}, fullfile(chanTargetDir{ii},fileList.tifNames{ii}),...
                'Compression','none')
        end
    end
