function cropStitchedSections(ROIs)
% When the user has asked for only one ROI, the original stitched images are cropped and replaced with this
%
% cropStitchedSections(ROIs)


s=findStitchedData;


[okToRun,diskStats]=stitchit.sampleSplitter.checkDiskUsage(ROIs,s);
if ~okToRun
    fprintf(['Cropped stacks will temporarilty need %0.1f GB.\n',...
        'Since only %0.1f GB is free we do not proceed\n'], ...
        diskStats.totalDiskUsageOfCroppedStackInGB, diskStats.diskUsage.freeGB)
    return
end

for ii=1:length(s)
    fprintf('Cropping directory %s\n', s(ii).stitchedBaseDir);
    cropDirName=['CROP_',s(ii).stitchedBaseDir];
    mkdir(cropDirName)
    for jj=1:length(s(ii).channel)
        fprintf('Cropping channel %d\n', s(ii).channelsPresent(jj));
        chanTargetDir = fullfile(cropDirName, num2str(s(ii).channelsPresent(jj)));
        mkdir(chanTargetDir)
        runCrop(s(ii).channel(jj), ROIs, s(ii).micsPerPixel, chanTargetDir)
    end


    
    allOK = stitchit.sampleSplitter.checkROIapplication(s(ii), cropDirName);
    if allOK
      % TODO: delete original stack and replace it with cropped
    end
    
end

 

function runCrop(fileList, ROIs, micsPix, chanTargetDir)


    parfor ii = 1:length(fileList.tifNames)
        fname = fullfile(fileList.fullPath, fileList.tifNames{ii});
        imToCrop =  stitchit.tools.openTiff(fname);
        croppedImage=stitchit.sampleSplitter.getROIfromImage(imToCrop,micsPix, ROIs);
        imwrite(croppedImage{1}, fullfile(chanTargetDir,fileList.tifNames{ii}), 'Compression','none')
    end
