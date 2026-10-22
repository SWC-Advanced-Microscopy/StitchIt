function imStack8Bit = stackTo8Bit(imStack)
    % Convert a 3D image stack from 16 bit to 8 bit
    %
    % stitchit.tools.stackTo8Bit(imStack)
    %
    % Purpose
    % Convert a image stack from 16 bit to 8 bit. The stack is scaled
    % by the maximum value.
    %
    % Inputs
    % imStack - input stack
    %
    % Outputs
    % imStack - the 8 bit exported stack
    %
    %
    % Rob Campbell, SWC 2026


    % Do each plane separately to avoid making a huge array
    imStack8Bit = zeros(size(imStack), 'uint8');
    maxPixelValue = single(max(imStack(:)));

    for ii=1:size(imStack,3)
        tSlice = single(imStack(:,:,ii));
        tSlice = (tSlice./maxPixelValue) * 255;

        imStack8Bit(:,:,ii) = uint8(floor(tSlice));


    end

