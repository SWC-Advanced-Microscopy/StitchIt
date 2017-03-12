function pixelPos = stagePos2PoxelPos(param,micsPerPixel)
% Convert a mosaic structure to tile pixel positions
%
% Purpose
%
% Use the number of microns per pixel in the INI file along with the 
% stage positions in microns in the Mosaic file in order to determine where
% each tile should go (in pixels).
%
%
% Inputs
% param - the Moasic data as a structure
% micsPerPixel - [pixel resolution rows, pixel resolution columns]
%
%
%
% Rob Campbell - Basel 2014



%Values in pixels for placing each tile
pixResRow=micsPerPixel(1);
pixResCol=micsPerPixel(2);


% Microns from Mosaic file (note, it seems to be correct that we swap X and Y) 
% TODO: a bit of consistency might be nice. Should look into why
Y=param.stageLocations.reported.X;
X=param.stageLocations.reported.Y;


%Convert Y to match with the transposed tiles
%This is because tile positions were transposed when they were read
%by generateTileIndex. This avoids needing to flip and transpose the 
%tiles
Y = Y * -1;
Y = Y - min(Y);



stagePos = [Y,X];
stagePos = round(stagePos/10); %because the values are microns * 10



%However, we have cropped images so let's take that into account 
%TODO: cropping doesn't seem to have been taken into account?

stagePos=bsxfun(@minus,stagePos,min(stagePos)); %start at zero


%There is some evidence of back-lash on alternate tiles. Can we fix this with a 
%hard correction? The answer is mainly yes, but we somtimes have to flip a key
%line, so something is really wrong. That should be needed.
doBacklash=0;
if doBacklash

    %TODO: YUK - use mod to find odd and even rows
    r=~repmat(0,sum(stagePos(:,2)==0),1); %TEEK: seems this needs to be flipped between brains from time time. WHY?
    rows=[];
    while length(rows)<length(stagePos) %logicals to indicate alternate rows
        r=~r;
        rows=[r;rows];
    end
    stagePos(logical(rows),1)=stagePos(logical(rows),1)-16;
end



%Convert to pixels
stagePos(:,1)=stagePos(:,1)-min(stagePos(:,1));

pixelPos(:,1) = stagePos(:,1) / pixResRow;
pixelPos(:,2) = stagePos(:,2) / pixResCol;

pixelPos = round(pixelPos + 1);