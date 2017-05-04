function [nbchannels, nbplanes] = size_from_scanimage(~,tifpath)
    % load ScanImage metadata from TIFF header, v5 or v2016

    % default values for channels/zplanes in case of early return
    nbchannels = [];
    nbplanes = [];

    % retrieve header info from first frame
    tif_obj = Tiff(tifpath, 'r');
    tags.ImageDescription = safe_get_tags(tif_obj, 'ImageDescription', '');
    tags.Software = safe_get_tags(tif_obj, 'Software', '');
    tif_obj.close()

    % zplane/channel info from ScanImage metadata, v2016
    if ~isempty(tags.Software) && ~strcmp(tags.Software, 'MATLAB')
        channel_txt = regexp(tags.Software, ...
            'SI\.hChannels\.channelSave = (.+?)(?m:$)', 'tokens', 'once');
        zplane_txt = regexp(tags.Software, ...
            'SI\.hFastZ\.numFramesPerVolume = (.+?)(?m:$)', 'tokens', 'once');

    % zplane/channel info from ScanImage metadata, v5
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
end

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
end
