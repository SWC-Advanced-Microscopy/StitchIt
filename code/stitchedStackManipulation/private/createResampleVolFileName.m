function downsampledFname = createResampleVolFileName(channel,targetDims)
    % Generate a file name for saving resampled volumes
    %
    % function downsampledFname = createResampleVolFileName(targetDims)
    %
    % Purpose
    % This function is called by resampleVolume and downsampleAllChannels
    %
    % Inputs
    % chanel - scalar defining the channel number
    % targetDims - 1 by 2 vector indicating xy and z pixel size
    %
    % Outputs
    % downsampledFname - the file name
    %
    % 



    paramFile=getTiledAcquisitionParamFile;
    if startsWith(paramFile, 'recipe')
          % We have BakingTray Data
          downsampledFname = strcat('ds_', paramFile(8:end-4));
    else
        error('No recipe file found')
    end

    if mod(targetDims(1),1)==0
          downsampledFname=[downsampledFname, sprintf('_%d',targetDims(1))];
    else
          downsampledFname=[downsampledFname, sprintf('_%0.1f',targetDims(1))];
    end

    if mod(targetDims(2),1)==0
          downsampledFname=[downsampledFname, sprintf('_%d',targetDims(2))];
    else
          downsampledFname=[downsampledFname, sprintf('_%0.1f',targetDims(2))];
    end


    % See if we can obtain the channel name from the scan settings file
    % TODO -- dupe with stitchedPlanesToVolume
    if exist('scanSettings.mat','file')
        load('scanSettings')
        % Process channel name to ready it for insertion into file name
        chName = lower(scanSettings.hPmts.names{channel});
        chName = strrep(chName,' ','_');
        chName = ['_',chName];
    else
        chName='';
    end


    downsampledFname=[downsampledFname, sprintf('_ch%02d%s',channel,chName)];


    % remove nasty characters
    downsampledFname = strrep(downsampledFname,':','');
