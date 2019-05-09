function createPlaneListTxt(stitchedDir,targetDir, prefix)
% Create a text file per channel with the list of image planes
%
% function createPlaneListTxt(stitchedDir,targetDir, prefix)
%
%
% Purpose
% For loading images in Fiji or processing all the planes in batch, having
% a sorted list of planes per channel is useful. 
% 
% Inputs
% stitchedDir - string defining stitched data directory
% targetDir - a string defining the directory to save data to
% prefix - a string that will be added before each file name
%
% Example
% Create a file list for all channels of one experiment and save the text
% files in to the local directory
% cropStitched('stitchedImages_100/','.','best_exp_')
%
%
% Antonin Blot
%
% See Also: generate_MaSIV_list


if strcmp(stitchedDir(end),filesep)
    stitchedDir(end)=[];
end

if strcmp(targetDir(end),filesep)
    targetDir(end)=[];
end

if ~exist(stitchedDir,'dir')
    error('Can not find %s',stitchedDir)
end

if ~exist(targetDir,'dir')
    mkdir(targetDir)
end

root_dir = pwd();

targets = dir(stitchedDir);
for iT = 1:numel(targets)
    dir_name = targets(iT).name;
    if startsWith(dir_name, '.')
        continue
    end
    chan_dir = fullfile(stitchedDir, dir_name);
    if ~targets(iT).isdir
        continue
    end
    
    fprintf('Doing channel %s\n',dir_name)
    
    tifs = dir(fullfile(chan_dir,'*.tif'));
    if isempty(tifs)
        error('    No tiffs found in %s',stitchedDir);
    else
        fprintf('    Found %d images\n',length(tifs))
    end
    target_file = fullfile(targetDir, sprintf('%sch_%s.txt', prefix, dir_name));
    file_names = {tifs.name};
    file_names = cellfun(@(x) fullfile(root_dir, chan_dir, x), file_names, 'un', 0);
    txt = strjoin(file_names, '\n');
    fprintf('    Writing %s.\n', target_file)
    fileID = fopen(target_file, 'w');
    fprintf(fileID, txt);
    fclose(fileID);                
end
fprintf('Done\n')
end
