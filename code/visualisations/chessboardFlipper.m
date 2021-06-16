function chessboardFlipper(chessIm,maxVal)
% Animate the chessboard sitching to show the overlays only and have the flip between tiles
%
% function chessboardflipper(chessIm,maxVal)
%
% Purpose
% Displays overlapping tile regions and flips back and forth between the two
% to show how much overlap there is between tiles. Think of this as an 
% animated chessboard stitch in grayscale.
%
% Inputs
% chessIm - the output of chessboardStitch
% maxVal - 1000 by default. The max plotted value. Brighter values clipped
%
% Outputs
% none
%
% Rob Campbell - SWC 2021
%
% Also see:
% chessboardStitch



if nargin<2
    maxVal=1000;
end

% Max a mask so as to not plot stuff that is not common. 
imMask = chessIm.im(:,:,1) .* chessIm.im(:,:,2);
imMask = cast(imMask>1,class(chessIm.im));


%plot
clf 
im = imagesc(chessIm.im(:,:,1));
caxis([0,maxVal])
colormap gray
axis equal tight


fprintf('\n\nPress ctrl-c to break animation loop\n')


% flip
n=1;
while 1

    if n==1
        im.CData = chessIm.im(:,:,1) .* tmp;
    else
        im.CData = chessIm.im(:,:,2) .* tmp;
    end

    n=n*-1;
    drawnow
    pause(0.1)
end
