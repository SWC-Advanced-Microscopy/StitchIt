function cropStitchedSections(ROIs)
% Make cropped stitched image series with one or more ROIs
%
% stitchit.sampleSplitter.cropStitchedSections(ROIs)
%
% Inputs
% ROIs - this is the output of stitchit.sampleSplitter.returnParams
%.       see help stitchit.sampleSplitter for a use case



s=findStitchedData;


[okToRun,diskStats]=stitchit.sampleSplitter.checkDiskUsage(ROIs,s);
if ~okToRun
    fprintf(['Cropped stacks will temporarily need %0.1f GB.\n',...
        'Since only %0.1f GB is free we do not proceed\n'], ...
        diskStats.totalDiskUsageOfCroppedStackInGB, diskStats.diskUsage.freeGB)
    return
end

uncroppedDir = ['UncroppedStacks_', datestr(now,'yymmdd_HHMM'),'_DELETE_ME_DELETE_ME']; %things we crop successfully go here

%The following cell array defines globs associated with meta-data that we want to move to the new sample folder
%directories and also out of the sample root. This is somewhat hard-coded, but should encompass enough
%stuff to work well even we change things around a bit,
metaDataFilesToMove = {'*.yml','*.txt','*.mat','*.ini','*FINISHED*'};

% Remove any of the meta-data files that don't exist from the list,
% otherwise we get an error when trying to copy or move them.
for ii=length(metaDataFilesToMove):-1:1
  tmpD = dir(metaDataFilesToMove{ii});
  if isempty(tmpD)
    metaDataFilesToMove(ii)=[];
  end
end

%Log to disk the autoROI performance if applicable
fname='StitchIt_Log.txt';
stitchit.tools.writeLineToLogFile(fname,sprintf('Running sample splitter on data\n'))
if isfield(ROIs,'autoROIperformance') && ~isempty(ROIs(1).autoROIperformance)
    stitchit.tools.writeLineToLogFile(fname,sprintf('Auto-ROI performance:\n'))
    stitchit.tools.writeLineToLogFile(fname,ROIs(1).autoROIperformance.msg);
end

atLeastOneWorked=false; % True if at least one of the full size image stacks cropped successfully

% There are multiple ROIs we assume there are multiple samples so set it up as such
if length(ROIs)>1
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


        for kk=1:length(cropDirName)
            %Make channel directory
            chanTargetDir{kk} = fullfile(cropDirName{kk}, num2str(s(ii).channelsPresent(jj)));
            fprintf('Making directory %s\n', chanTargetDir{kk})
            mkdir(chanTargetDir{kk})
        end

        runCrop(s(ii).channel(jj), ROIs, s(ii).micsPerPixel, chanTargetDir) %This is where the work is done
    end

    %Check if everything worked
    allOK = zeros(1,length(cropDirName));
    for kk=1:length(cropDirName)
        allOK(kk) = stitchit.sampleSplitter.checkROIapplication(s(ii), cropDirName{kk});
    end
    
    if all(allOK)
        atLeastOneWorked=true;
        % Move the original stitched data out to the back up directory
        targetBackUpDir = fullfile(uncroppedDir,s(ii).stitchedBaseDir);
        fprintf('Making %s\n', targetBackUpDir)
        mkdir(targetBackUpDir)

        fprintf('Moving %s%s* to %s\n',s(ii).stitchedBaseDir, filesep, targetBackUpDir);

        %TODO! This seemed to not be copying the stitched root dir,
        %only the chan dirs. Don't know why. So I've made it into a
        %2-step process to sort this out. Perhaps we'll get funny 
        %nesting, but hopefully it will not overwrite stuff
        movefile([s(ii).stitchedBaseDir,filesep,'*'], targetBackUpDir)
        if exist(s(ii).stitchedBaseDir,'dir')
          rmdir(s(ii).stitchedBaseDir,'s')
        end


        %If necessary, copy meta-data to new sample directories and then move out to back-up dir
        if length(ROIs)>1
            for kk=1:length(ROIs)
                cellfun(@(x) copyfile(x,ROIs(kk).name), metaDataFilesToMove)
            end
            cellfun(@(x) movefile(x, uncroppedDir), metaDataFilesToMove)
        end
    end % if all(allOK)

end % ii=1:length(s)


if atLeastOneWorked

    movefile('downsampled*',uncroppedDir) %move to the backup directory
    cDIR=pwd;
    
    if length(ROIs)>1
      for ii=1:length(ROIs)
        % Loop through the new ROI directories and make downsampled data
        try
            cd(ROIs(ii).name)
            renameSample(ROIs(ii).name)
            downsampleAllChannels %re-build the downsampled stacks
        catch ME
            disp(ME.message)
        end
        cd(cDIR)
      end % for ii
    else
       %Rename cropped dirs
       d=dir('CROP_*');
       for ii=1:length(d)
         if ~d(ii).isdir
           continue
         end
         movefile(d(ii).name,strrep(d(ii).name,'CROP_',''));
       end
       
       downsampleAllChannels %re-build the downsampled stacks
    end
    

end % if atLeastOneWorked





%--------------------------------------------------------------------------------
function runCrop(fileList, ROIs, micsPix, chanTargetDir)
    % This function runs the crop operation in parallel on one channel

    userConfig=readStitchItINI;

    parfor ii = 1:length(fileList.tifNames)
        % Load the image
        fname = fullfile(fileList.fullPath, fileList.tifNames{ii});
        imToCrop =  stitchit.tools.openTiff(fname);

        croppedImage=stitchit.sampleSplitter.getROIfromImage(imToCrop,micsPix, ROIs);
        for jj=1:length(croppedImage)
            if userConfig.stitching.saveCompressed == true
                imwrite(croppedImage{jj}, fullfile(chanTargetDir{jj},fileList.tifNames{ii}),...
                    'Compression','lzw')
            else
                imwrite(croppedImage{jj}, fullfile(chanTargetDir{jj},fileList.tifNames{ii}),...
                        'Compression','none')
            end
        end
    end
