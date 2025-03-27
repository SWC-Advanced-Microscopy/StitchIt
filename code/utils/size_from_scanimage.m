function [nbchannels, nbplanes] = size_from_scanimage(tifpath)
    % Return number of channels and number of frames from a ScanImage TIFF
    %
    % function [nbchannels, nbplanes] = size_from_scanimage(tifpath)
    %
    % Purpose
    % Given the path to a ScanImage TIFF, return the number of channels and the number of
    % optical planes as two integers. This function handles both the old ScanImage v5
    % metadata and the new metadata format for these data from version 2016 onwards.
    %
    % Inputs
    % tifpath - relative or absolute path to ScanImage TIFF file.
    %
    % Outputs
    % nbchannels - number of channels in the TIFF
    % nbplanes - number of optical planes in the TIFF
    %
    %
    % Rob Campbell


    % default values for channels/zplanes in case of early return
    nbchannels = [];
    nbplanes = [];

    % retrieve header info from first frame
    tif_obj = Tiff(tifpath, 'r');
    tags.ImageDescription = safe_get_tags(tif_obj, 'ImageDescription', '');
    tags.Software = safe_get_tags(tif_obj, 'Software', '');
    tif_obj.close()


    % zplane/channel info from ScanImage metadata version 2016 onward
    if ~isempty(tags.Software) && ~strcmp(tags.Software, 'MATLAB')
        channel_txt = regexp(tags.Software, ...
            'SI\.hChannels\.channelSave = (.+?)(?m:$)', 'tokens', 'once');
        zplane_txt = regexp(tags.Software, ...
            'SI\.hFastZ\.numFramesPerVolume = (.+?)(?m:$)', 'tokens', 'once');

    % zplane/channel info from ScanImage metadata, v5 and before
    else
        channel_txt = regexp(tags.ImageDescription, ...
            'scanimage\.SI\.hChannels\.channelSave = (.+?)(?m:$)', ...
            'tokens', 'once');
        zplane_txt = regexp(tags.ImageDescription, ...
            'scanimage\.SI\.hFastZ\.numFramesPerVolume = (.+?)(?m:$)', ...
            'tokens', 'once');
    end


    % stop if no zplane/channel info found
    if isempty(channel_txt) || isempty(zplane_txt)
        return
    end

    % convert channel and z-plane info to scalar
    nbchannels = numel(str2num(channel_txt{:}));  %#ok<ST2NM>
    nbplanes = str2double(zplane_txt{:});
    if isnan(nbplanes)
        nbplanes = 1;
    end

end % size_from_scanimage


function tag_value = safe_get_tags(tif_obj, tag_name, default_value)
    % helper function to safely retrieve a tag from a TIFF object
    tag_value = default_value;
    try
        tag_value = tif_obj.getTag(tag_name);
    catch err
        if ~strcmp(err.identifier, 'MATLAB:imagesci:Tiff:tagRetrievalFailed')
            rethrow(err);
        end
    end
end % safe_get_tags
