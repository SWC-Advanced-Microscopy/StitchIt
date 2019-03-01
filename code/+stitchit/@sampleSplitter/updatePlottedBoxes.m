function updatePlottedBoxes(obj)
    % Update the boxes plotted on the orig view window

        %Delete all boxes and re-plot
        delete(obj.hBox)
        obj.hBox=[];

        data=obj.hDataTable.Data;
        for ii=1:size(data)
            za = cell2mat(obj.hDataTable.Data(ii ,1:4));
            boxXvaluesForPlot = [za(1), za(1)+za(3), za(1)+za(3), za(1), za(1)];
            boxYvaluesForPlot = [za(2), za(2), za(2)+za(4), za(2)+za(4), za(2)];

            obj.hBox(end+1) = plot(boxXvaluesForPlot, boxYvaluesForPlot, '-c','LineWidth',1, ...
                                'parent', obj.origViewImAxes);
        end

        set(obj.hBox(obj.selectedRow), 'color', 'r','LineWidth', 2)

        % Do not display the preview window if there are no ROIs
        if isempty(obj.hBox)
            delete(obj.hPreview)
        end
end