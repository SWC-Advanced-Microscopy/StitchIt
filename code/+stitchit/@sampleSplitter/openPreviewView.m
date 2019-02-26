function openPreviewView(obj,ROIcoords,rotQuantity)
    % openPreviewView
    %
    % This methods opens (or updates) a figure window that shows the 
    % content of the current ROI
    
    if nargin<3
        rotQuantity=0;
    end
    f = findobj('Tag',obj.previewName);

    if ~isempty(f)
        obj.hPreview = f;
    else
        obj.hPreview = figure;
        obj.hPreview.Tag = obj.previewName;
        obj.hPreview.MenuBar = 'none';
        obj.hPreview.ToolBar = 'none';
        obj.hPreview.Color=[1,1,1]*0.1;
        obj.hPreview.Name = 'Current ROI'
        obj.hPreview.Position(1) = obj.hMain.Position(1)-obj.hMain.Position(3);
        obj.previewImAxes = axes('Position',[0.025,0.025,0.95,0.95],'Parent',obj.hPreview);
    end

    % Pull out image data based on ROI coordinates
    size1 = ROIcoords(2)+ROIcoords(4);
    size2 = ROIcoords(1)+ROIcoords(3);
    imToPlot = obj.origImage(ROIcoords(2):size1, ROIcoords(1):size2);
    imToPlot = rot90(imToPlot,rotQuantity);

    % Size the window to the image retaining the current top/left corner position
    pos = obj.hPreview.Position;
    obj.hPreview.Position(3) = size(imToPlot,2);
    obj.hPreview.Position(4) = size(imToPlot,1);
    obj.hPreview.Position(2) = obj.hPreview.Position(2) + pos(4) - obj.hPreview.Position(4);

    imagesc(imToPlot,'Parent',obj.previewImAxes);
    colormap gray
    axis off equal 
end % previewView