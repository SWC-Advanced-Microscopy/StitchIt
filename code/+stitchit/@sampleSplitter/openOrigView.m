function openOrigView(obj)
    % openOrigView
    %
    % This methods opens (or updates) a figure window that shows the 
    % content of the origImage field, which is the image we will cut up
    % into one or more ROIs using the stitchit.sampleSplitter class.

    delete(findobj('Tag',obj.origViewName)) %Ensure we don't open duplicates
    obj.hOrigView = figure;
    obj.hOrigView.Tag = obj.origViewName;
    obj.hOrigView.MenuBar = 'none';
    obj.hOrigView.ToolBar = 'none';
    obj.hOrigView.Color=[1,1,1]*0.1;
    obj.hOrigView.Name = 'Original stack projection';

    obj.hOrigView.CloseRequestFcn = []; % Closing main window will close this

    % Size the window to the image
    obj.hOrigView.Position(3) = size(obj.origImage,2);
    obj.hOrigView.Position(4) = size(obj.origImage,1);

    obj.hOrigView.Position(2) = obj.hMain.Position(2)-obj.hOrigView.Position(4)-25;

    obj.origViewImAxes = axes('Position',[0.025,0.025,0.95,0.95],'Parent',obj.hOrigView);
    imagesc(obj.origImage,'Parent',obj.origViewImAxes);

    colormap gray
    axis off equal
    hold on
end % openOrigView