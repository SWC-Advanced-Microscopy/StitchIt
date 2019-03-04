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
end % if length(ROIs)


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
    end

    for jj=1:length(s(ii).channel)
        fprintf('Cropping channel %d\n', s(ii).channelsPresent(jj));

        allOK = zeros(1,length(cropDirName));
        for kk=1:length(cropDirName)
            %Make channel directory
            chanTargetDir{kk} = fullfile(cropDirName{kk}, num2str(s(ii).channelsPresent(jj)));
            mkdir(chanTargetDir{kk})
            allOK(kk) = stitchit.sampleSplitter.checkROIapplication(s(ii), cropDirName{kk});
        end

        runCrop(s(ii).channel(jj), ROIs, s(ii).micsPerPixel, chanTargetDir) %This is where the work is done
    end



    if all(allOK)
        atLeastOneWorked=true;
        % Move the original stitched data to the cropped directory
        fprintf('Moving %s to %s\n',s(ii).stitchedBaseDir, uncroppedDir);
        %TODO! This seems to not be copying the stithced root dir
        %only the chan dirs. Don't know why. So make the following
        %2-step process to sort this out. Check if it works!
        mkdir(fullfile(uncroppedDir,s(ii).stitchedBaseDir))
        movefile(s(ii).stitchedBaseDir, fullfile(uncroppedDir,s(ii).stitchedBaseDir))


        %If necessary, copy meta-data to new sample directories
        if length(ROIs)>1
            for kk=1:length(ROIs)
                %Following copy operation is somewhat hard-coded, but should encompass enough
                %stuff to work well even we change things around a bit,
                cellfun(@(x) copyfile(x,ROIs(kk).name), {'*.yml','*.txt','*.mat','*.ini'})
            end
        end
    end

end % ii=1:length(s)


if atLeastOneWorked
  movefile('downsampledMHD*',uncroppedDir)
  cDIR=pwd;
  for ii=1:length(ROIs)
    try
      cd(ROIs(ii).name)
      downsampleAllChannels %re-build the downsampled stacks
    catch
    end
    cd(cDIR)
  end
  
end





%--------------------------------------------------------------------------------
function runCrop(fileList, ROIs, micsPix, chanTargetDir)


    parfor ii = 1:length(fileList.tifNames)
        % Load the image
        fname = fullfile(fileList.fullPath, fileList.tifNames{ii});
        imToCrop =  stitchit.tools.openTiff(fname);

        croppedImage=stitchit.sampleSplitter.getROIfromImage(imToCrop,micsPix, ROIs);
        for jj=1:length(croppedImage)
            imwrite(croppedImage{jj}, fullfile(chanTargetDir{jj},fileList.tifNames{ii}),...
                'Compression','none')
        end
    end
