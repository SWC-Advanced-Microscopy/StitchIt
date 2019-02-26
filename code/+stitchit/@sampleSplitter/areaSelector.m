function areaSelector(obj,~,~)
    %select a sub-region of original image
    h = imrect(obj.origViewImAxes);

    obj.lastDrawnBox = round(wait(h));
    delete(h)
    za = obj.lastDrawnBox;

    %Ensure box isn't larger than the image
    if za(1)<1
        za(1)=1;
    end
    if za(2)<1
        za(2)=1;
    end
    size1 = za(2)+za(4);
    size2 = za(1)+za(3);

    if (size1+za(2)) > size(obj.origImage,1)
        size1 = size(obj.origImage,1);
    end
    if (size2+za(1)) > size(obj.origImage,2)
        size2 = size(obj.origImage,2);
    end

    % Add to the data table
    boxXvaluesForPlot = [za(1), za(1)+za(3), za(1)+za(3), za(1), za(1)];
    boxYvaluesForPlot = [za(2), za(2), za(2)+za(4), za(2)+za(4), za(2)];
    if isempty(obj.hDataTable.Data)
        obj.hDataTable.Data  = [num2cell(za), 0, 'ROI 1'];
        obj.hBox = plot(boxXvaluesForPlot, boxYvaluesForPlot, '-r','LineWidth',2);
        
    else
        tmp = [num2cell(za), 0, sprintf('ROI %d', length(obj.hBox)+1)];

        obj.hDataTable.Data  = [obj.hDataTable.Data; tmp];
        tmp = plot(boxXvaluesForPlot, boxYvaluesForPlot, '-r','LineWidth',2);
        obj.hBox = [obj.hBox, tmp];
        set([obj.hBox(1:end-1)],'color','c','LineWidth',1)
    end
    


    obj.openPreviewView(za)

    if length(obj.hBox)>0
        obj.hButton_deleteROI.Enable='On';
    end

end % Close areaSelector