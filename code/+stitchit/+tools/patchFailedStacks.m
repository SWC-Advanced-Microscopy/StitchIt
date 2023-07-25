function patchFailedStacks(pathsToPatch)
% Fix z-stacks where final depth is missing
%
% function patchFailedStacks(pathsToPatch)
%
% Purpose
% Since around ScanImage Basic 2021, there are rare cases of the
% final image plane being missing in a small number of tiles. This
% function uses the output of findIncompleteStacks to add a final extra
% depth to the files listed in pathsToPatch. This works because in all
% cases only the final depth is missing. The original files are retained
% in a folder placed under rawData.
%
% Inputs
% pathsToPatch - output of findIncompleteStacks
%
% Rob Campbell - 2022 SWC


if ~iscell(pathsToPatch)
    return
end


% Directory in which original data are stored
backup_dir = ['rawData',filesep,'stacksWithMissingPlanes'];

if ~exist(backup_dir)
    mkdir(backup_dir)
end

% We need to know how many images to clone.
md = readMetaData2Stitchit;
nchans = length(md.sample.activeChannels);


for ii = 1:length(pathsToPatch)
    t_file = pathsToPatch{ii};
    [p,fn,ext] = fileparts(t_file);

    % Skip anything that has already been processed.
    % We know it's been processed because it exists as
    % a backup.
    if exist(fullfile(backup_dir,[fn,ext]))
        fprintf('Skipping already corrected file: %s\n',t_file);
        continue
    end

    % Make a copy
    copyfile(t_file,backup_dir)


    im = stitchit.tools.loadTiffStack(t_file);

    im = cat(3,im,im(:,:,end-2:end));

    tInfo=imfinfo(t_file);
    stitchit.tools.writeSignedTiff(int16(im),t_file,tInfo(1).Software,true)
end
