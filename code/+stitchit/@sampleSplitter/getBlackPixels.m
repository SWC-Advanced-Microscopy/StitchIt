function BW = getBlackPixels(obj)
    % Get black pixels indicating areas that were not imaged
    %
    % function BW = getBlackPixels(obj)
    %
    % Purpose
    % Set all black/blank pixels to 1. This is to assess how well the 
    % autoROI worked. Note that there seem to be isolated black pixels 
    % in the sample also. These aren't non-imaged areas. To exclude these
    % we do a little filtering here. 


    BW = obj.imStack;
    for ii=1:size(obj.imStack,3)
        BW(:,:,ii) = imfill(obj.imStack(:,:,ii)>0,'holes');
    end

    BW = ~BW;
