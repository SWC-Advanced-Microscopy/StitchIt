function varargout=findStitchedData(dataDir)
% Return information on what data have been stitched: image size, channel, etc
%
% OUT = findStitchedData(dataDir)
%
% Purpose
% Returns what data have been stitched. Information displayed to 
% screen unless an output argument is requested. In this case
% a structure is returned and nothing is displayed to screen.
% Change to sample directory before running.
%
% Inputs
% dataDir - optional. By default all stitched directories are searched
%          based on the field subdir.stitchedDirBaseName from the INI 
%          file. However, if path to a directory is provided then this
%          this scanned and the information on the stitched files
%          within it are returned. This is useful for summarising 
%          the results of ROI cropping operations.
%
% Outputs
% OUT - optional output structure containing info on stitched data
%
%
% Rob Campbell - SWC 2019


OUT = [];

% Get name of stitched image sub-dir
if nargin<1
    sINI=readStitchItINI;
    stitchedDirs = dir([sINI.subdir.stitchedDirBaseName,'*']);
else
    if ~ischar(dataDir)
        fprintf(['findStitchedData - input argument dataDir should be ',...
            'the relative or absolute path to a data directory\n'])
        return
    end
    if ~exist(dataDir,'dir')
        fprintf('findStitchedData - can not find directory %s\n', dataDir)
        return
    end
    [stitchedDirs.folder,stitchedDirs.name ] = fileparts(dataDir);
    if strcmp(stitchedDirs.folder,'.')
      stitchedDirs.folder = pwd;
    end
end

% Get microns per pixel of raw data
m=readMetaData2Stitchit;
micsPerPixel = mean([m.voxelSize.X, m.voxelSize.Y]);


% Loop through available sample directories and build up information on what is in them
for ii=1:length(stitchedDirs)
    if ~isdir(stitchedDirs(ii).name)
        continue
    end    

    % Filter stuff that isn't a directory
    thisStitchedDir = dir(stitchedDirs(ii).name);
    thisStitchedDir(~[thisStitchedDir.isdir]) = [];

    % Now we can loop through  is left and report it as stitched 
    theseChans = [];
    n=1;
    for jj=1:length(thisStitchedDir)
        if isempty(regexp(thisStitchedDir(jj).name,'^\d+$'))
            % Skip if the directory name doesn't contain only numbers
            continue
        end

        % Log details of what has been stitched in each channel
        thisChannelDir = fullfile(thisStitchedDir(jj).folder,thisStitchedDir(jj).name);
        OUT(ii).stitchedBaseDir = stitchedDirs(ii).name;
        OUT(ii).channel(n).chanIndex = str2num(thisStitchedDir(jj).name);
        OUT(ii).channel(n).fullPath = thisChannelDir;
        tifsInChan = dir(fullfile(thisChannelDir,'section*.tif'));
        OUT(ii).channel(n).numTiffs = length(tifsInChan);
        OUT(ii).channel(n).tifNames = {tifsInChan(:).name};
        OUT(ii).channel(n).diskSizeInBytes = sum([tifsInChan(:).bytes]);
        OUT(ii).channel(n).diskSizeInMB = sum([tifsInChan(:).bytes])/1024^2;
        OUT(ii).channel(n).diskSizeInGB = sum([tifsInChan(:).bytes])/1024^3;
        n=n+1;
    end

    % Summarise contents of this stitched image directort
    OUT(ii).diskSizeInGB = sum([OUT(ii).channel(:).diskSizeInGB]);
    OUT(ii).channelsPresent = [OUT(ii).channel(:).chanIndex];
    OUT(ii).numTiffsEqualInAllChannels = all([OUT(ii).channel(:).numTiffs]==OUT(ii).channel(1).numTiffs);

    % Record voxel size
    tok = regexp(stitchedDirs(ii).name,'\w+_(\d+)','tokens');
    resizeFactorFromDirName=str2num(tok{1}{1})/100;
    OUT(ii).micsPerPixel = micsPerPixel/resizeFactorFromDirName;
    OUT(ii).zSpacingInMicrons = m.voxelSize.Z;
end



if nargout>0
    if ~isempty(OUT)
        %Ensure the output structure is sorted in increasing pixel size order
        [~,ind] = sort([OUT(:).micsPerPixel]);
        OUT = OUT(ind);
    end
    varargout{1}=OUT;
else 
    % Report to screen if no function output requested by user
    fprintf('\n')
    for ii=1:length(OUT)
        fprintf(' Directory name: %s\n Available channels: ', OUT(ii).stitchedBaseDir)
        fprintf(repmat('%d ',[1,length(OUT(ii).channelsPresent)]), OUT(ii).channelsPresent)
        fprintf('\n')
        fprintf(' Microns per pixel: %0.2f\n', OUT(ii).micsPerPixel)
        fprintf(' Occupied disk space: %0.1f GB\n\n', OUT(ii).diskSizeInGB) 
    end

end

if isempty(stitchedDirs)
    fprintf('Found no stitched image directories in %s\n', pwd);
end
