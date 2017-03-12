function mask=tileCoords2MaskIm(tileCoords)
% Produce a mask that can be used by the GIST routine.
%
% Purpose
% Load the tile coordinates CSV file or accept it as a matrix. Convert it 
% to a uint8 matrix (or uint16 if we have more than 256 tiles) that can be
% saved to disk and used as a mask image by the GIST binaries.
%
% Inputs
% tileCoords - a matrix or file name describing the positions of tiles or a string pointing
%              to a csv file that contains such a matrix. 

%

if isstr(tileCoords)
    if ~exist(tileCoords)
        fprintf('%s can not load tile coords file %s\n',mfilename,tileCoords)
        mask=[];
        return
    end
    tileCoords = csvread(tileCoords,1);
end

if length(tileCoords)>2^8-1
    imClass = 'uint16';
else
    imClass = 'uint8';
end

%Pre-allocate
[xMax,ind] = max(tileCoords(:,1));
xMax = xMax + tileCoords(ind,2) - 1;

[yMax,ind] = max(tileCoords(:,3));
yMax = yMax + tileCoords(ind,4) - 1;

mask = zeros(yMax,xMax,imClass);
origSize=size(mask);

%Fill the mask
%We will randomise the IDs just because it's easier to debug visually. The algorithm doesn't care
R=randperm(length(tileCoords));
for ii=1:length(tileCoords)
    %The indexes of the stitched image where we will be placing this tile
    xPos = (tileCoords(ii,1):tileCoords(ii,1)+tileCoords(ii,2)-1);
    yPos = (tileCoords(ii,3):tileCoords(ii,3)+tileCoords(ii,4)-1);

    mask(yPos,xPos)=R(ii);
end


if any(origSize-size(mask))
    fprintf('%s - Mask started out at %dx%d and is now %dx%d\n',mfilename,origMask,size(mask))
end


if any(mask(:)==0)
    fprintf('%s WARNING: not all pixels in the mask have been assigned\n',mfilename)
end



