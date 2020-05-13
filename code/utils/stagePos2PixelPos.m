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
%
% Rob Campbell - Basel 2014
%              - Updated May 2020 to handle BakingTray instead of Orchestrator data

if nargin<3
    offsetXY=[];
end

%Values in pixels for placing each tile
pixResRow=micsPerPixel(1);
pixResCol=micsPerPixel(2);


stagePos = round(stagePos * 1E3); % To get into microns


%However, we have cropped images so let's take that into account 
%TODO: cropping doesn't seem to have been taken into account?
if isempty(offsetXY)
    offsetXY = min(stagePos); %start at zero
else
    offsetXY = round(offsetXY * 1E3);
end

stagePos = stagePos - offsetXY; % Subtract the offset


%Convert to pixels
pixelPos(:,1) = stagePos(:,1) / pixResRow;
pixelPos(:,2) = stagePos(:,2) / pixResCol;


pixelPos = round(pixelPos + 1);
