function pixelPos = stagePos2PoxelPos(stagePos,micsPerPixel,offsetXY)
% Convert a mosaic structure to tile pixel positions
%
% function pixelPos = stagePos2PoxelPos(stagePos,micsPerPixel,offsetXY)
%
% Purpose
% Use the number of microns per pixel in the INI file along with the 
% stage positions in microns in the Mosaic file in order to determine where
% each tile should go (in pixels).
%
%
% Inputs
% stagePos - A matrix where each row is a stage position. First column is
%                  X stage position in mm. Second is Y stage position in mm.
% micsPerPixel - [pixel resolution rows, pixel resolution columns]
% offsetXY - optional: [xstagePos,ystagePos] the "origin" stage location in mm.
%           By default the minimum stage position in "stagePos" is used. 
%           This option is to allow stitching of sections with with different ROIs.
%
% Outputs
% pixelPos -  This n by 2 array is fed into stitcher to place the tiles forming a 
%             stitched image. The first column is the pixel row the second is the 
%             pixel column index.
%
%
% Rob Campbell - Basel 2014
%              - Updated May 2020 to handle only BakingTray instead of Orchestrator data
%
%
% See also:
% peekSection, stitchSection, tileLoad

if nargin<3
    offsetXY=[];
end

%Values in pixels for placing each tile
pixResRow=micsPerPixel(1);
pixResCol=micsPerPixel(2);

stagePos = round(stagePos * 1E3); % Convert from mm to microns


if isempty(offsetXY)
    offsetXY = min(stagePos); %start at zero
else
    tileSize=abs(mode(diff(stagePos(:,1))));
    offsetXY = round( (offsetXY) * 1E3)+tileSize;
end

stagePos = stagePos - offsetXY; % Subtract the offset

% Convert from microns to pixels
pixelPos = bsxfun(@rdivide,stagePos,[pixResRow,pixResCol]);
pixelPos = round(pixelPos + 1);
