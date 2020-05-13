function pixelPos = stagePos2PoxelPos(stageLocations,micsPerPixel)
% Convert a mosaic structure to tile pixel positions
%
% function pixelPos = stagePos2PoxelPos(stageLocations,micsPerPixel)
%
% Purpose
% Use the number of microns per pixel in the INI file along with the 
% stage positions in microns in the Mosaic file in order to determine where
% each tile should go (in pixels).
%
%
% Inputs
% stageLocations - A matrix where each row is a stage position. First column is
%                  X stage position in mm. Second is Y stage position in mm.
% micsPerPixel - [pixel resolution rows, pixel resolution columns]
%
%
%
% Rob Campbell - Basel 2014
%.             - Updated May 2020 to handle BakingTray instead of Orchestrator data



%Values in pixels for placing each tile
pixResRow=micsPerPixel(1);
pixResCol=micsPerPixel(2);


% Stage X is image Y
Y=stageLocations(:,1);
X=stageLocations(:,2);




stagePos = [Y,X];
stagePos = round(stagePos * 1E3); % To get into microns



%However, we have cropped images so let's take that into account 
%TODO: cropping doesn't seem to have been taken into account?

stagePos=bsxfun(@minus,stagePos,min(stagePos)); %start at zero


%Convert to pixels
pixelPos(:,1) = stagePos(:,1) / pixResRow;
pixelPos(:,2) = stagePos(:,2) / pixResCol;

pixelPos = round(pixelPos + 1);