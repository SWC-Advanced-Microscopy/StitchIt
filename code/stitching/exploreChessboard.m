function exploreChessboard(im,thresh)
% Display chessboard stitched images in a way that is easy to navigate
% 
%  function exploreChessboard(im,thresh)
%
% Purpose
% Compares change in stitching quality upon tweaking of stitching parameters. 
% Works in tandem with the function chessBoardStitch. 
% To zoom, use the mouse wheel. To pan, click and drag the right mouse button.
%
% Inputs
% im - The structure returned by chessBoardStitch. If this has a length of 2, then
%      two images are placed side by side and their axes linked. 
%
%
%
% Rob Campbell - September 2019, SWC


if nargin<2 || isempty(thresh)
  thresh=500;
end

%Reconnect to the same figure again
hFig=findobj('tag',mfilename);
if ~isempty(hFig)
  figure(hFig);
else
  hFig = figure;
  set(hFig,'tag',mfilename);
end


clf(hFig)

%Threshold
for ii=1:length(im)
  im(ii).im(im(ii).im>thresh)=thresh;
end


if length(im)==1
  showFusedImage(im.im)

elseif length(im)==2
  for ii=1:2
    ax(ii)=subplot(1,2,ii);
    showFusedImage(im(ii).im)
  end
  linkaxes([ax(1),ax(2)])
end

imgzoompan('Magnify',1.2)
    tilefigs([1,2],0)

function showFusedImage(im)
  c=imfuse(im(:,:,1),im(:,:,2),'falsecolor','Scaling','joint','ColorChannels',[1 2 0]);
  imshow(c)

function tilefigs(tile,border)
% <cpp> tile figure windows usage: tilefigs ([nrows ncols],border_in pixels)
% Restriction: maximum of 100 figure windows
% Without arguments, tilefigs will determine the closest N x N grid
%Charles Plum                    Nichols Research Corp.
%<cplum@nichols.com>             70 Westview Street
%Tel: (781) 862-9400             Kilnbrook IV
%Fax: (781) 862-9485             Lexington, MA 02173
maxpos  = get (0,'screensize'); % determine terminal size in pixels
maxpos(4) = maxpos(4) - 25;
hands   = get (0,'Children');   % locate fall open figure handles
hands   = sort(hands);          % sort figure handles
numfigs = size(hands,1);        % number of open figures
maxfigs = 100;
if (numfigs>maxfigs)            % figure limit check
        disp([' More than ' num2str(maxfigs) ' figures ... get serious pal'])
        return
end
if nargin == 0
  maxfactor = sqrt(maxfigs);       % max number of figures per row or column
  sq = [2:maxfactor].^2;           % vector of integer squares
  sq = sq(find(sq>=numfigs));      % determine square grid size
  gridsize = sq(1);                % best grid size
  nrows = sqrt(gridsize);          % figure size screen scale factor
  ncols = nrows;                   % figure size screen scale factor
elseif nargin > 0 
  nrows = tile(1);
  ncols = tile(2);
  if numfigs > nrows*ncols
    disp ([' requested tile size too small for ' ...
        num2str(numfigs) ' open figures '])
        return
  end
end
if nargin < 2
  border = 0;
else
  maxpos(3) = maxpos(3) - 2*border;
  maxpos(4) = maxpos(4) - 2*border;
end
xlen = fix(maxpos(3)/ncols) - 30; % new tiled figure width
ylen = fix(maxpos(4)/nrows) - 45; % new tiled figure height
% tile figures by postiion 
% Location (1,1) is at bottom left corner
pnum=0;
for iy = 1:nrows
  ypos = maxpos(4) - fix((iy)*maxpos(4)/nrows) + border +25; % figure location (row)
  for ix = 1:ncols
        xpos = fix((ix-1)*maxpos(3)/ncols + 1) + border+7;     % figure location (column)
        pnum = pnum+1;
    if (pnum>numfigs)
                break
        else
          figure(hands(pnum))
      set(hands(pnum),'Position',[ xpos ypos xlen ylen ]); % move figure
        end
  end
end

