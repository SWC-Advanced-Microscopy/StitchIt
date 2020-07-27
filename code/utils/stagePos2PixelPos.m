function pixelPos = stagePos2PoxelPos(stagePos,micsPerPixel,originStageXY)
% Convert a mosaic structure to tile pixel positions
%
% function pixelPos = stagePos2PoxelPos(stagePos,micsPerPixel,originStageXY)
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
% originStageXY - optional: [xstagePos,ystagePos] the "origin" stage location in mm.
%           By default this is empty and nothing is done. If provided, it should be
%           the maximum Y and X values for the sample being stitched. 
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
    originStageXY=[];
end


%Values in pixels for placing each tile
pixResRow=micsPerPixel(1);
pixResCol=micsPerPixel(2);

stagePos = round(stagePos * 1E3); % Convert from mm to microns

if isempty(originStageXY)
    shiftPixels=[0,0];
else
    originStageXY = originStageXY * 1E3;
    d = originStageXY - max(stagePos); %How much we will shift the ROI by in mm.
    shiftPixels = round(d ./ [pixResRow,pixResCol]);
end





% Convert from microns to pixels
pixelPos = bsxfun(@rdivide,stagePos,[pixResRow,pixResCol]);
pixelPos = round(pixelPos + 1);


% BakingTray has the convention whereby more positive X stage (that which moves the sample 
% left/right) locations are to the right and more positive Y stage locations are away from 
% the user. The origin of the preview images (those that appear in its GUI) produced by 
% BakingTray is front/left location of the imaged area. i.e. the most positive position on
% the X and Y stages. So that the stitched images have the origin as the microscope stage
% front/left position we perform the following operation:
pixelPos = abs(pixelPos - max(pixelPos) - 1);

% This avoids having to flip the stitched image left/right and up/down so that it matches
% the orientation of the data shown in BakingTray. Further, it means that the origin of the 
% image matches the microscope front/left. This makes working with the data easier for the
% purposes of the auto-ROI, etc. 


%Shift the area if needed
pixelPos = pixelPos + shiftPixels;

% The following functions are internal and used for debugging only
function checkRange(pos)
    % report the range of positions.
    r = max(pos) - min(pos);
    disp(r)
