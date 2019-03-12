function varargout=autofindBrains(im,pixelSize,doPlot)
    % autofindBrains
    %
    % function varargout=autofindBrains(im,pixelSize,doPlot)
    % 
    % Purpose
    % Automatically draw boxes around brains in a down-sampled image. 
    % Optional output arg returns the box coords as [x,y,xWidth,yWidth]
    %
    % 
    % Inputs
    % im - downsampled 2D image
    % pixelSize - optional, 25 (microns/pixel) by default
    % doPlot - if true, display image and overlay boxes. false by default
    %
    %
    % Rob Campbell - SWC, 2019


    if nargin<2 || isempty(pixelSize)
        pixelSize = 25; 
    end
    if nargin<3
        doPlot=false;
    end


    %Threshold (NOTE: hard-coded. Worry about this only if it presents a problem)
    BW = im>20;

    % Remove crap
    SE = strel('square',round(150/pixelSize));
    BW = imerode(BW,SE);
    BW = imdilate(BW,SE);

    % Add a border of 250 microns around each brain
    SE = strel('square',round(250/pixelSize));
    BW = imdilate(BW,SE);



    %Look for objects at that occupy least 15% of the image area
    sizeThresh = prod(size(im)) * 0.15;
    [L,indexedBW]=bwboundaries(BW,'noholes');
    for ii=length(L):-1:1
        thisN = length(find(indexedBW == ii));
        if thisN < sizeThresh
            L(ii)=[]; % Delete small stuff
        end
    end

    if isempty(L)
        fprintf('No brains found!\n')
    end

    % Optionally display image with calculated boxes
    if doPlot
        %Make figure window if needed
        f=findobj('Tag',mfilename);

        if isempty(f)
            f=figure
            set(f,'Tag',mfilename);
        end

        clf(f)
        ax=axes('Position', [0.025, 0.025, 0.95, 0.95], ...
            'Parent',f);


        imagesc(im,'Parent',ax)
        hold(ax,'on')

        colormap gray

        hold on 
        for ii=1:length(L)
            tL = L{ii};
            xP = [min(tL(:,2)), max(tL(:,2))];
            yP = [min(tL(:,1)), max(tL(:,1))];

            plot([xP(1), xP(2), xP(2), xP(1), xP(1)], ...
                 [yP(1), yP(1), yP(2), yP(2), yP(1)], ...
                 '-r', 'Parent', ax)
        end
        hold(ax,'off')
        axis equal off
    end


    % Optionally return coords of each box
    if nargout>0
        colormap gray

        OUT = {};
        for ii=1:length(L)
            tL = L{ii};
            xP = [min(tL(:,2)), max(tL(:,2))];
            yP = [min(tL(:,1)), max(tL(:,1))];
            OUT{ii} = [xP(1), yP(1), xP(2)-xP(1), yP(2)-yP(1)];
        end
        varargout{1}=OUT;
    end

