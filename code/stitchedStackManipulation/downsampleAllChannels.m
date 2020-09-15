function downsampleAllChannels(voxelSize,fileFormat)
% function downsampleAllChannels(voxelSize,fileFormat)
%
% Purpose
% Downsample all channels to MHD or TIFF files with a voxel size defined by
% "voxelSize". If voxelSize is missing, we use 25 microns. Then copy
% all to a single directory. 
%
% Inputs [optional]
% voxelSize - a scalar or vector (makes 50 and 25 micron stacks by default. Also 10 microns)
%             if the pixel size warrents it. It defines the target voxel
%             size of the resample operation. If a vector it makes downsampled
%             stacks at each voxel size
% fileFormat - 'MHD' or 'TIFF'. TIFF by default
%
%
% Example: make 10 micron stacks
% downsampleAllChannels(10)
%
% Rob Campbell - SWC, 2018
%
% See also - resampleVolume, rescaleStitched

stitchedDataInfo=findStitchedData;
if isempty(stitchedDataInfo)
    fprintf('No stitched data found by %s. Quitting\n', mfilename)
    return
end

if nargin<1 || isempty(voxelSize)
    % Choose pyramid to make based upon the resolution
    if stitchedDataInfo.micsPerPixel<4 && stitchedDataInfo.zSpacingInMicrons<=10
        voxelSize=[50,25,10];
    else
        voxelSize=[50,25];
    end
end

voxelSize = sort(voxelSize);

if nargin<2 || isempty(fileFormat)
      fileFormat='tiff';
end


coreDownsampleDir = 'downsampled_stacks';
if ~exist(coreDownsampleDir,'dir')
    mkdir(coreDownsampleDir)
    fprintf('Making %s\n', coreDownsampleDir)
end

% Make sub-directories to hold downsampled stacks of a particular size
dsDirName={};
for ii=1:length(voxelSize)
    tDir = fullfile(coreDownsampleDir,sprintf('%03d_micron',voxelSize(ii)));
    if ~exist(tDir,'dir')
        fprintf('Making %s\n', tDir)
        mkdir(tDir)
    end
    dsDirName{ii}=tDir;
end



% Which channels are available?
chan = stitchedDataInfo.channelsPresent;

% Downsample those channels
for ii = 1:length(chan)
    tChan = chan(ii);
    fprintf('Making downsampled volume for channel %d\n', tChan)

    if length(voxelSize)==1
        resampleVolume(tChan,voxelSize,fileFormat,dsDirName{1});
    else
        tVol = resampleVolume(tChan,voxelSize(1),fileFormat,dsDirName{1});
        metaData = readMetaData2Stitchit;

        for jj=2:length(voxelSize)
            rescaleBy = voxelSize(1)/voxelSize(jj);
            targetSize = size(tVol) * rescaleBy;
            newVol = imresize3(tVol,targetSize);


            fname = createResampleVolFileName(tChan,[voxelSize(jj),voxelSize(jj)]);
            fname = fullfile(dsDirName{jj},fname);
            fprintf('Saving to %s\n', fname)
            if strcmpi('tiff',fileFormat)
                stitchit.tools.save3Dtiff(newVol,[fname,'.tif'])
            elseif strcmpi('mhd',fileFormat)
                stitchit.tools.mhd_write(newVol,fname,[1,1,1])
            end

            % Write to log file
            fid = fopen([fname,'.txt'],'w');
            fprintf(fid,'Downsampling %s\nAcquired on: %s\nDownsampled: %s\n', metaData.sample.ID, metaData.sample.acqStartTime, datestr(now));
            if strcmp('tiff',fileFormat)
                fprintf(fid,'downsample file name: %s.tif\n',fname);
            end

            fprintf(fid,'Rescaled %d micron volume by %0.2f to write a %d micron volume\n', ...
                voxelSize(1),rescaleBy,voxelSize(jj));
            fclose(fid);


        end

    end
end
