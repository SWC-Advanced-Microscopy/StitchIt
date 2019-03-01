function addROI(obj, coords)
    % Add a ROI with supplied coords in standard MATLAB format [x,y,xSize, ySize]
    % After ROI is added it is plotted



    %Ensure box isn't larger than the image
    if coords(1)<1
        coords(1)=1;
    end
    if coords(2)<1
        coords(2)=1;
    end

    boxEndHeightPos = coords(2)+coords(4); %Pixel where ROI will end along rows
    boxEndWidthPos = coords(1)+coords(3); %Pixel where ROI will end along cols

    if boxEndHeightPos > size(obj.origImage,1)
        fprintf('Correcting overflow ROI height from %d pixels ', coords(4));
        boxEndHeightPos = size(obj.origImage,1); %cap to image
        coords(4) = boxEndHeightPos-coords(2);
        boxEndHeightPos = coords(2)+coords(4);
        fprintf('to %d pixels\n',coords(4));
    end

    if boxEndWidthPos > size(obj.origImage,2)
        fprintf('x=%d boxEndWidthPos %d\n',coords(1), boxEndWidthPos)
        fprintf('Correcting overflow ROI width from %d pixels ',coords(3));
        boxEndWidthPos = size(obj.origImage,2); %cap to image
        coords(3) = boxEndWidthPos-coords(1);
        boxEndWidthPos = coords(1)+coords(3);
        fprintf('to %d pixels\n',coords(3));
    end

    % Values of teh current box to be added to the data table
    boxXvaluesForPlot = [coords(1), boxEndWidthPos, boxEndWidthPos, coords(1), coords(1)];
    boxYvaluesForPlot = [coords(2), coords(2), boxEndHeightPos, boxEndHeightPos, coords(2)];


    if isempty(obj.hDataTable.Data)
        obj.hDataTable.Data = [num2cell(coords), 0, 'ROI_1'];
        obj.selectedRow=1;
    else
        tmp = [num2cell(coords), 0, sprintf('ROI_%d', length(obj.hBox)+1)];
        obj.hDataTable.Data  = [obj.hDataTable.Data; tmp];
        obj.selectedRow=size(obj.hDataTable.Data,1);
    end
    
    obj.updatePlottedBoxes;
    obj.openPreviewView(coords); %TODO: get this from the data table and the selectedRow?

    if size(obj.hDataTable.Data,1);
        obj.hButton_deleteROI.Enable='On';
    end
