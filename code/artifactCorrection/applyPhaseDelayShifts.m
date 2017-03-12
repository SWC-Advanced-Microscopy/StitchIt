function corrected=applyPhaseDelayShifts(im,stats,overlap,verbose)

% Divide image into bands and correct phase delay in each band based upon pre-calculated coefficients
%
% function corrected=correctPhaseDelayShifts(im,stats,overlap,verbose)
%
%
% PURPOSE
% Correct bidirectional scanning artifacts using coefficients produced by calcPhaseDelayShifsts.m
% See that function for more details.
%
%
% INPUTS
% im - a single image or an image stack.  
% stats - The output of calcPhaseDelay. If im is a stack, then length(stats) should equal
%         size(im,3). If stats is missing or empty, then stats are calculated automatically.
% overlap - The number of pixels overlap between bands. This is to avoid wrapping 
%           artifacts. This value should be at least the magnitude of the largest 
%           expected phase shift. Likely 2 to 4 would work. Default is 4. If empty,
%           default value is used. The largest allowed shift is overlap-1 pixels.
% verbose - the verbosity level. 0 means no output. 1 prints details to screen 
%
%
% OUTPUTS
% corrected - The corrected image or image stack.
%
%
% EXAMPLES
% C = applyPhaseDelayShifts(myImage,myStats);
% C = applyPhaseDelayShifts(myImage);
%
%
% ALSO SEE
% calcPhaseDelayShifts, visualisePhaseDelayShifts
%
% 
% Rob Campbell - Basel, 2014


%Parse input arguments
if nargin<2
    stats=[];
end

if ~isempty(stats) & size(im,3) ~= length(stats)
    error('Expected size(im,3) to equal length(stats)')
end

if nargin<3 || isempty(overlap)
    overlap=4;
end

if nargin<4 || isempty(verbose)
    verbose=0;
end


if isempty(stats) %Calculate the shifts if none were provided
    stats=calcPhaseDelayShifts(im,[],verbose);
end


if length(stats(1).xShifts)==1
    overlap=0; %If we only have one band, this should be zero
else
    %Zero shifts larger *or equal* to the overlap under the assumption that such shifts are not real. 
    %This will also result in a modest speed improvement as cases with all zero shifts are 
    %skipped
    for ii=1:length(stats)
        f=find(abs(stats(ii).xShifts)>overlap);
        stats(ii).xShifts(f)=0;
    end
end


%Loop over image layers if this is a stack with a recursive function call
if size(im,3)>1 
    corrected=ones(size(im),class(im)); %Pre-allocate the output array


    %EXPERIMENTAL: Use median shifts. This doesn't generally work as well
    useMedianShifts=0;

    if useMedianShifts
        sh=[stats.xShifts];
        sh=reshape(sh,length(stats),length(stats(1).xShifts));
        sh=median(sh);
    end

    for ii=1:size(im,3) %parfor doesn't help here
        if verbose, fprintf('%d. ',ii), end

        if useMedianShifts
            stats(ii).xShifts=sh;
        end

        %Do not go through the procedure if all shifts are zero
        if any(stats(ii).xShifts)
            corrected(:,:,ii) = applyPhaseDelayShifts(im(:,:,ii),stats(ii),overlap,verbose);
        else
            corrected(:,:,ii) = im(:,:,ii);
        end

    end
    return
end



if any([size(im,1),size(im,2)]-stats.imSize)
    fprintf('Warning! Image correction stats are based on an image of a different size to the supplied\n')
end



%------------------------------
%Begin the correction 
corrected=im;
xShifts=stats.xShifts;

nBands=length(xShifts);
movingRows=stats.movingRowsStart:2:size(im,1); %The rows of the original image that constitute the "moving" sub-image



for ii=1:nBands %Loop through the vertical bands 

    %Get the index values that define the first and last pixels of each band
    first=stats.colX(ii);
    last=stats.colX(ii+1);
    origCols=first:last; %Indexes of band


    %Extract a band (with a buffer) from the image to correct. 
    if ii==1 %first column
        last=last+overlap;
        correctedBand=im(:,first:last);
        correctedBand=[repmat(correctedBand(:,1),1,overlap),correctedBand];
    elseif ii==nBands %last column
        first=first-overlap;
        correctedBand=im(:,first:last);
        correctedBand=[correctedBand,repmat(correctedBand(:,end),1,overlap)];
    else %other columns
        first=first-overlap;
        last=last+overlap;
        correctedBand=im(:,first:last);
    end


    if verbose
        fprintf('Correcting shifts at: %d/%d. Zeroed %d shifts. Shifting %d to %d by %d pixels: ',...
            ii,nBands,length(f),first,last,xShifts(ii))
    end

    %shift the "moving" rows in this band
    correctedBand(movingRows,:) = circshift(correctedBand(movingRows,:), xShifts(ii),2);
    
    %Trim off overlap
       correctedBand(:,1:overlap)=[];
       correctedBand(:,end-overlap+1:end)=[];


    if verbose
        fprintf('Replacing %d pixels between %d and %d\n',...
            size(correctedBand,2), origCols(1), origCols(end))
    end

    %Insert the corrected band into the image
    corrected(:,origCols)=correctedBand;

end %for ii=1:nBands

