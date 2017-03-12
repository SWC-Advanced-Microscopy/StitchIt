function pixelPositions=tilePixels2StitchedPixels(pixels,tileSize,tilePixelPos)

% Given a set of pixel indexes in a tile, the tile size, and the position (top left of tile) in the stitched image,
% calculate where in the full stitched image, the supplied pixels will fall. 
%
%
% INPUTS
% pixels - the pixel coordinates in the tile that we want to map to locations in the stitched image.
%          these should be an n by 2 array of subcripts. If it's a vector of more than length 2 we 
%          assume these are indexes and comvert.
% tileSize - scalar defining the size of the image. This is after cropping. (images are square)
% tilePixelPos - the location of the tile's top left pixel in the stitched image. This is a vecor of 
%                length 2: [row,column]
% 
%
% OUTPUTS
% pixelPositions - the location of "pixels" in the stitched image (in pixels).
%
%
%
% Rob Campbell - Basel 2014



%Convert from index values to array subscripts if needed
if length(pixels)>2 & prod(size(pixels))==length(pixels)
    [I,J] = ind2sub([tileSize,tileSize],pixels);
    pixels = [I',J'];
end



%Now we just add this to the tile's top left pixel position
pixelPositions = bsxfun(@plus,pixels,tilePixelPos);