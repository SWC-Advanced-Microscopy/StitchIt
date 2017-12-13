function [] = writeSignedTiff(vnData, sTarget, sSoftware, bOverwrite)
%writeSignedTiff Write signed tiff images (int16)
%
% Call:
% write_signed_tiff(vnData, sTarget, sSoftware, bOverwrite)
%
% Inputs
% - vnData: matrix of data (3D)
% - sTarget: path to tiff file.
% - sSoftware: software field of the the tiff header. Default: "Matlab"
% - bOverwrite: overwrite target if existing. Default: false.
%
% No Output


% Parse inputs
if ~exist('sSoftware', 'var') || isempty(sSoftware)
    sSoftware = 'Matlab';
end
if ~exist('bOverwrite', 'var') || isempty(bOverwrite)
    bOverwrite = false;
end

% Check for target
if ~bOverwrite && exist(sTarget, 'file')
    error('File already exists. Use bOverwrite or change target')
end

% Write the tiff to disk
tagstruct = struct();
tagstruct.ImageDescription = '';
nframes = size(vnData,3);


% set TIFF tags
tagstruct.ImageLength = size(vnData,1);
tagstruct.ImageWidth = size(vnData,2);
tagstruct.Compression = Tiff.Compression.None;
tagstruct.BitsPerSample = 16;
tagstruct.SamplesPerPixel = 1;
tagstruct.RowsPerStrip = size(vnData,1);
tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
tagstruct.Software = sSoftware;
tagstruct.SampleFormat = 2;     % signed int

% write frames
targetTiff = Tiff(sTarget,'w');
targetTiff.setTag(tagstruct);
targetTiff.write(squeeze(vnData(:,:,1)));
if nframes > 1
    for indf = 2:nframes
        % every framerperfile, create a new TIFF
        % append to existing TIFF
        targetTiff.writeDirectory();
        targetTiff.setTag(tagstruct);
        targetTiff.write(vnData(:,:,indf));
    end
end
targetTiff.close()

end

