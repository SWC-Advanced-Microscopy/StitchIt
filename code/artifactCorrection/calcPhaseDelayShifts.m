function stats=calcPhaseDelayShifts(im,nBands,verbose)

% Divide image into nBands vertical strips and calculate the phase delay in each
%
% function stats=calcPhaseDelayShifts(im,nBands,verbose)
%
%
% PURPOSE
% Bidirectional scanning introduces a phase delay between the outgoing an returning
% scan paths of the x mirror. Every other scan line is in-sync but adjacent lines 
% are out of sync. This can be corrected at acquisition time by manually setting a 
% phase delay parameter. This doesn't always produce perfect results, however. 
% Potential reasons for this include:
% a) phase different between adjacent scan lines differs with distance from the turn-around
%    points due to acceleration and deceleration of the scanner. 
% b) possible drift in the ideal correction value 
% c) acquisition software re-assigns pixels in random ways by trying (and failing) to correct 
%    for bidirectional scanning errors on-line. 
%
% For the above reasons, it's worth trying an off-line correction. 
%
% This function divides up the image into a set of vertical bands and calculates the phase 
% delay between adjacent scan lines separately for each. We do this because the delay is 
% is different toward the edges than in the middle of the image. This function simply 
% calculates coefficients, which can be saved and re-used to save time. The function
% "applyPhaseDelayShifts" uses the coefficients structure returned by this function to 
% correct an image. 
%
%
% INPUTS
% im - a single monochromatic image or image stack. 
% nBands - how many bands to divide the image into. An odd number of suggested. A 
%          reasonable value would be 9, which is the default value. If empty, default
%          value is used.
% verbose - the verbosity level. 0 means no output. 1 reports shifts to screen.
%
%
% OUTPUTS
% stats - a structure containing the shifts, band locations, corrected row 
%         identities, etc. Feed this to applyPhaseDelayShifts to apply a correction to
%         an image.
% 
%
%
% ALGORITHM 
% 1) Divide image in "nBands" non-overlapping vertical strips.
% 2) For each strip pull out odd and even scan lines and treat these as two separate 
%    images, say "image_A" and "image_B".
% 3) Treat image_A as the "fixed" image and register image_B to it using cross-correlation,
%    which we do in the Fourier domain for speed (code adapted from FEX #1840 by Manuel Guizar).
% 4) Extract whole-pixel shifts for each band. 
% 5) Knowing the band positions, pixel shift value, and which image rows constitute "image_A" and
%    "image_B", we can shift into register the alternate scan lines using applyPhaseDelayShifts
%
% KNOWN ISSUES
% 1) We are using whole pixel shifts only because this is slightly faster and because applying 
%    sub-pixel shifts can create subtle image artifacts, particularly for noisy images.
% 2) If the phase difference between image_A and image_B is fairly large (with "large" being)
%    application-dependent) then features in the image may appear noticeably translated following
%    correction. This might be an issue if we are applying this correction to, say, different 
%    different optical sections of an image stack, where the same features should be at least 
%    partially visible across slices. Shifting *both* sets of scan lines around an average value
%    should take care of this when the required correction is >1 pixel.  
%
%
% 
% ALSO SEE
% applyPhaseDelayShifts, visualisePhaseDelayShifts
%
% 
% Rob Campbell - Basel 2014




%Parse input arguments
if nargin<2 | isempty(nBands)
    nBands=1;
end

if nargin<3 | isempty(verbose)
    verbose=0;
end



%Loop over image layers (if this is an image stack) using a recursive function call
if size(im,3)>1
    stats = calcPhaseDelayShifts(im(:,:,1),nBands,verbose);
    stats = repmat(stats,1,size(im,3));
    parfor ii=2:size(im,3) %Requires parallel computing toolbox
        stats(ii)=calcPhaseDelayShifts(im(:,:,ii),nBands,verbose);
    end
    return
end


imSize=size(im);

%make sure number of rows are even so the two images we create are the same size
if mod(size(im,1),2)
    im(end,:)=[];
end


%Calculate the start and end index of each vertical band
xSize = size(im,2);
colX  = floor(1:xSize/nBands:xSize);
colX(end+1) = xSize;



%Make the target (fixed) and moving images that we will register to estimate the shift
targetRows = 1:2:size(im,1); %These will stay still
movingRows = 2:2:size(im,1); %These will be shifted

xShifts = ones(1,nBands); %pre-allocate array that will contain the shift values in x

if verbose
    fprintf('Shifts: ');
end


for ii=1:nBands
    imageCols = colX(ii):colX(ii+1);
    %Calculate the x shift in pixels 
    xShifts(ii) = dftCalcXShift(im(targetRows,imageCols),...
                                  im(movingRows,imageCols));
end


if verbose
    fprintf('%d ',xShifts)
    fprintf(' for image size %d by %d\n',size(im))
end



%Prepare output structure
stats.xShifts         = single(xShifts);      %Shift magnitude in pixels
stats.targetRowsStart = int16(targetRows(1)); %Which rows will be fixed
stats.movingRowsStart = int16(movingRows(1)); %Which rows will move
stats.colX            = int16(colX);          %The band locations
stats.imSize          = imSize;               %The size of the image for error checking




% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
function xShift = dftCalcXShift(imA,imB)
% Calculate image shift in x only by DFT-based cross-correlation. not sub-pixel.
%
% function xShift = dftCalcXShift(imA,imB)
%
% Returns whole pixel shift in x. Registers imB to imA
%
% Original function by Manuel Guizar (2007) in the FEX. This version by RAAC (2014).
% This version is heavily stripped down to increase speed.
% 
% J.R. Fienup and A.M. Kowalczyk, "Phase retrieval for a complex-valued 
% object by using a low-resolution image," J. Opt. Soc. Am. A 7, 450-458 
% (1990).


imA=fft2(imA);
imB=fft2(imB);

[m,n]=size(imA);

CC = ifft2(imA.*conj(imB));
[max1,ind1] = max(CC);
[max2,ind2] = max(max1);

cloc=ind2; %Cols (which we care about)
nd2 = fix(n/2); %Cols 

%Calculate column shift
if cloc > nd2
    xShift = cloc - n - 1;
else
   xShift = cloc - 1;
end
