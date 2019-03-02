function previewROIs(obj,plane,channel)
    % Partition a plane using the current ROIs and show the result on screen.
    % Images are downsampled for clarity.
    %
    % Inputs
    % plane - optional, if missing or empty choose plane from the middle of the stack
    %         plane is a scalar indicating which stitched TIFF to work on. 
    %         1 is first in dir listing.
    % channel - optional, if missing or empty choose the last available channel.
    %           This argument should be a scalar



    % Find out what has been stitchen
    if isempty(obj.stitchedDataInfo)
        return
    end
    ROIs=obj.returnROIparams;
    if isempty(ROIs)
        return
    end

    stitchedDataInd=length(obj.stitchedDataInfo); %choose lowest available resolution for fasted loading
    stitchedDir = obj.stitchedDataInfo(stitchedDataInd).stitchedBaseDir;
    chans=obj.stitchedDataInfo(stitchedDataInd).channelsPresent;

    if nargin<3 || isempty(channel)
        channel = chans(end);
    end

    thisChanInd = find(chans==channel);
    chanData=obj.stitchedDataInfo(stitchedDataInd).channel(thisChanInd);
    nAvailTiffs = length(chanData.tifNames);

    if nargin<2 || isempty(plane) || plane>nAvailTiffs
        plane = round(nAvailTiffs/2);
    end


    fname = fullfile(chanData.fullPath, chanData.tifNames{plane});

    im =  stitchit.tools.openTiff(fname);


    % Obtain a cell array of ROI images
    splitIms = stitchit.sampleSplitter.getROIfromImage(im, ...
                obj.stitchedDataInfo(stitchedDataInd).micsPerPixel,...
                ROIs);


    if isempty(splitIms)
        fprintf('previewROIs recieved no ROIs from +sampleSplitter.getROIfromImage\n');
        return
    end


    %Resize the ROI images for plotting on the screen
    p = numSubPlots(length(splitIms));
    screenWidth=get(0,'MonitorPositions');
    screenWidth=screenWidth(1,3);
    figWidth = round((screenWidth/p(2))*0.9);



    stitchit.plot.pfigure

    for ii=1:length(splitIms)
        subplot(p(1),p(2),ii)
        thisWidth = size(splitIms{ii},2);
        imagesc( imresize(splitIms{ii}, figWidth/thisWidth) )
        c=caxis;
        caxis([c(1),c(2)*0.5]) %make the image brighter
        axis equal off
    end
    colormap gray




    % - - - - - - - - - - - - - - - - - - - - - - - 
    function [p,n]=numSubPlots(n)
        % Determine how to arange the subplots for prettiness

        while isprime(n) & n>4, 
            n=n+1;
        end

        p=factor(n);

        if length(p)==1
            p=[1,p];
            return
        end

        while length(p)>2
            if length(p)>=4
                p(1)=p(1)*p(end-1);
                p(2)=p(2)*p(end);
                p(end-1:end)=[];
            else
                p(1)=p(1)*p(2);
                p(2)=[];
            end    
            p=sort(p);
        end


        %Reformat if the column/row ratio is too large: we want a roughly
        %square design 
        while p(2)/p(1)>2.5
            N=n+1;
            [p,n]=numSubplots(N); %Recursive!
        end
    end % numSubPlots


end % previewROIs