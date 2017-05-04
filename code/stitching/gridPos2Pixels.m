function pixelPositions=gridPos2Pixels(tileCoords,pixelRes,stepSize)
% Convert a tile's position to pixels. 
%
%    function pixelPositions=gridPos2Pixels(tileCoords,pixelRes,stepSize)
%
% Purpose
% Take an array of tile coordinates, the number of microns per pixel, and the step size
% and convert these to pixel location in the stitched image array. This function is called
% by stitchSection and peekSection. 
%
%
% DEFINITIONS
%  Tile coordinates - a two column matrix comprised of the row and column position 
%                     (index) of a tile in matrix. 
%  Pixel location of tile in stitched image - the position of the tile's top left 
%                                              pixel in the stitched array (units=pixels)   
%
%
% INPUTS
%  tileCoords - a matrix of tile coordinates. First column is tile row pos. Second is tile column position.
%                i.e. these are the row and column indexes of the tiles. 
%  pixelRes - The number of microns per pixel as obtained from the INI file. Either a scalar (in which
%             case we use the same number of microns per pixel in X and Y) or vector of length 2, in which
%             case we interpret it as being [pixResRows,pixResColumns]. If this value is missing, we load
%             it from disk from the INI file. 
%  stepSize - step in microns between one tile and the next. If a scalar the step size is the same in both
%             rows and columns. If a vector of length 2, it defines the step size along the rows (1) and
%             cols (2). By default stepSize is obtained from the parameter file. 
%        
%
% OUTPUTS
%  pixelPositions - n by 2 array. n tiles. [pixel row, pixel column]
%                   This tells us where the top left pixel of each tile should be. 
%
%
%  Rob Campbell - Basel, 2014


tileRow = tileCoords(:,1);
tileCol = tileCoords(:,2);


if nargin<2 | isempty(pixelRes) %read in number of microns per pixel if needed

    userConfig=readStitchItINI;
    if userConfig.micsPerPixel.usemeasured
        pixResR = userConfig.micsPerPixel.micsPerPixelMeasured;
        pixResC = userConfig.micsPerPixel.micsPerPixelMeasured;
    else
        pixResR = userConfig.micsPerPixel.micsPerPixelRows;
        pixResC = userConfig.micsPerPixel.micsPerPixelCols;
    end

else

    if length(pixelRes)==1
        pixResR = pixelRes;
        pixResC = pixelRes;
    elseif length(pixelRes)>1
        pixResR = pixelRes(1);
        pixResC = pixelRes(2);
    end

end


if nargin<3 | isempty(stepSize)
    M=readMetaData2Stitchit;
    stepSize = [M.TileStepSize.X,M.TileStepSize.Y];
end

if length(stepSize)==1
    stepSize=[stepSize,stepSize];
end


stepSizeR = stepSize(1)/pixResR;
stepSizeC = stepSize(2)/pixResC;


% Calculate the pixel positions. 
pixelPositions = [stepSizeR * (tileRow-1)  ,...
                  stepSizeC * (tileCol-1)  ];

pixelPositions=floor(pixelPositions)+1;

