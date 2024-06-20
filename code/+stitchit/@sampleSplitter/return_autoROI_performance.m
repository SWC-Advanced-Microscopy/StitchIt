function varargout=return_autoROI_performance(obj,ROIS)
    % Returns stats describing how well the autoROI worked based on the current drawn ROIs
    %
    % function stats=return_autoROI_performance(obj,ROIS)
    %
    %
    % Inputs
    % ROIS - optional. If not provided, it's extracted from the currently drawn ROIs

    if nargin<2
        ROIS = obj.returnROIparams;
    end


    % This is a 3D matrix defining all of the pixels in the volume 
    % that were not imaged
    BW = obj.getBlackPixels; % Non-imaged pixels are ones



    % We now make a mask that paints as ones all pixels that the user has chosen to keep.
    % This is based on the supplied or currently drawn ROIs. We want to estimate how much time
    % the autoROI saves. Therefore if there are multiple ROIs we also want to obtain
    % a single large ROI that encompasses all of them. Assuming a reasonable separation 
    % between the ROIs, this would be a better basis for comparison.

    % Make a mask where all pixels we keep are ones
    pixelsToKeep = zeros(size(BW,1:2));

    for ii=1:length(ROIS)
        t = ROIS(ii).ROI;
        pixelsToKeep(t(2):t(2)+t(4), t(1):t(1)+t(3)) = 1;
    end


    % This mask contains separate masks. So assessing WRT to this
    % is similar to assuming brains were imaged separately.
    pixelsToKeepNonPool = repmat(pixelsToKeep,[1,1,size(BW,3)]);


    % Make a single bounding box that captures all ROIs
    colsF = find(sum(pixelsToKeep,1)>0); 
    rowsF = find(sum(pixelsToKeep,2)>0); 

    pixelsToKeep = zeros(size(BW,1:2));
    pixelsToKeep(rowsF(1):rowsF(end),colsF(1):colsF(end))=1;
    pixelsToKeepPool = repmat(pixelsToKeep,[1,1,size(BW,3)]);


    % Now we can extract the stats according to the following logic
    imStacks.imagedPixelsThatAreDiscardedNonPool = BW==0 & pixelsToKeepNonPool==0;
    imStacks.nonImagedPixelsInAreaToKeepNonPool = BW==1 & pixelsToKeepNonPool==1;
    imStacks.imagedPixelsThatAreDiscardedPool = BW==0 & pixelsToKeepPool==0;
    imStacks.nonImagedPixelsInAreaToKeepPool = BW==1 & pixelsToKeepPool==1;


    stats.numDiscardedImagedPixelsNonPool = sum(imStacks.imagedPixelsThatAreDiscardedNonPool(:));
    stats.numSkipedPixelsInImagedAreaNonPool = sum(imStacks.nonImagedPixelsInAreaToKeepNonPool(:));
    stats.numDiscardedImagedPixelsPool = sum(imStacks.imagedPixelsThatAreDiscardedPool(:));
    stats.numSkipedPixelsInImagedAreaPool = sum(imStacks.nonImagedPixelsInAreaToKeepPool(:));

    stats.totalPixels = numel(BW);
    stats.numROIs = length(ROIS);


    % "savedPixels" tells us the net number of saved pixels. i.e. it's the number pixels in the ROI
    % that we didn't image minus the number of pixels we did image that were outside of the ROI.
    savedPixels = stats.numSkipedPixelsInImagedAreaNonPool - stats.numDiscardedImagedPixelsNonPool;


    % Then we express this as a percentage of the total imaged area. This is fair because the 
    % number of discarded but imaged pixels fall outside of the ROI. A value of 0% indicates 
    % that the number of saved pixels inside the ROI is perfectly offset by pixels imaged 
    % outside of the ROI. Negative numbers indicate that extra pixels were imaged. 
    stats.percentPixelsSavedNonPool = (savedPixels / stats.totalPixels)*100;

    savedPixels = stats.numSkipedPixelsInImagedAreaPool - stats.numDiscardedImagedPixelsPool;
    stats.percentPixelsSavedPool = (savedPixels / stats.totalPixels)*100;
    % The "pooled" percentage saved will be larger for multi-sample acquisitions because it assumes
    % the user is forced to image a single rectangle to cover all ROIs.


    % What proportion of the pixels in the cropped volume are non-imaged?
    stats.percentNonImagedPixelsInROIs = (stats.numSkipedPixelsInImagedAreaNonPool/sum(pixelsToKeepNonPool(:)))*100;

    % Message to write to the log file and/or print to screen
    stats.msg = sprintf('numROIs = %d, pooled: %0.1f%% saved, non-pooled: %0.1f%%, non-imaged pixels in ROIs: %0.1f%%\n', ...
        length(ROIS), stats.percentPixelsSavedPool, stats.percentPixelsSavedNonPool, stats.percentNonImagedPixelsInROIs);


    if nargout<1
        fprintf('%s',stats.msg)
    end

    if nargout>0
        varargout{1}=stats;
    end

    if nargout>1
        varargout{2}=imStacks;
    end