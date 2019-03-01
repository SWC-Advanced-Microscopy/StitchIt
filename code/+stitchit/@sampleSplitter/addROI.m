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

    boxHeight = coords(2)+coords(4);
    boxWidth = coords(1)+coords(3);

    if (boxHeight+coords(2)) > size(obj.origImage,1)
        boxHeight = size(obj.origImage,1);
        boxHeight-(coords(2)+coords(4));
        coords(4) = boxHeight-coords(2);
    end
    if (boxWidth+coords(1)) > size(obj.origImage,2)
        boxWidth = size(obj.origImage,2);
        coords(3) = boxWidth-coords(1);
    end

    % Values of teh current box to be added to the data table
    boxXvaluesForPlot = [coords(1), boxWidth, boxWidth, coords(1), coords(1)];
    boxYvaluesForPlot = [coords(2), coords(2), boxHeight, boxHeight, coords(2)];


    if isempty(obj.hDataTable.Data)
        obj.hDataTable.Data = [num2cell(coords), 0, 'ROI_1'];
        obj.selectedRow=1;
    else
        tmp = [num2cell(coords), 0, sprintf('ROI_%d', length(obj.hBox)+1)];
        obj.hDataTable.Data  = [obj.hDataTable.Data; tmp];
        obj.selectedRow=size(obj.hDataTable.Data,1);
    end
    
    obj.updatePlottedBoxes;
    obj.openPreviewView(coords); %TODO: have it get this from the data table and the selectedRow?

    if size(obj.hDataTable.Data,1);
        obj.hButton_deleteROI.Enable='On';
    end
