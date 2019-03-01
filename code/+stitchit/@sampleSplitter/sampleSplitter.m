classdef sampleSplitter < handle
    % stitchit.sampleSplitter 
    %
    % Purpose
    % This GUI is used for either cropping an acquisition with one sample or splitting up 
    % an acquisition with multiple samples into separate directories. Each directory will
    % contain its own recipe file and can be treated as an independent acquisition for the 
    % purposes of subsequent analyses. 
    %
    % 
    % Usage
    % - cd to sample directory
    % - run stitchit.sampleSplitter with first input arg being one of:
    %    a) Path to downsampled MHD stack of this sample
    %    b) Loaded image stack from (a)
    %    c) A 2D image that is the median or max intensity projection of that stack
    %
    % - Optionally a second input argument defines the number of microns per pixel. 
    %   If missing, this is either "25" or, if available, derived from the MHD name.
    % 
    % 
    % Rob Campbell, SWC, 2019


    properties
        origImage           % The image upon which we draw ROIs
        splitBrainParams    % A structure containing the ROIs and their orientations 
        micsPerPixel = 25   % scale of the downsampled image fed into this class
    end % properties

    properties (Hidden)
        hMain       % handle to main figure window containing the controls
        hOrigView   % handle to the window that displays the image for segmenting
        hPreview    % handle to the preview window showing what the segmented brain will look like

        hButton_drawBoxAddROI
        hButton_deleteROI
        hButton_autoFind
        hDataTable

        origViewImAxes % The image axes into which we will put the original image
        previewImAxes % The current preview of the selected area is here
        hBox          % Handles of plotted boxes

        mainGUIname = 'sampleSplitterMain'
        origViewName = 'origView'
        previewName = 'previewView'

        lastDrawnBox % When a new area is selected, it's stored here
        selectedRow  %Selected row in the table


        listeners={}
    end % hidden properties

    methods
        function obj = sampleSplitter(varargin)
            % first arg is an MHD file name, stack, or max/median projection
            % second arg (optional) is the number of microns per pixel. If missing,
            %. 25, unless it can be extracted from the MHD file fname. This valyue
            %. is stored in sampleSplitter.micsPerPixel


            if isempty(varargin)
                fprintf('Please provide an MHD filename, a stack, or an intensity projection\n')
                obj.delete
                return
            end

            if isnumeric(varargin{1}) && ndims(varargin{1}) == 2
                obj.origImage = varargin{1};
                fprintf('Assigning input as image to segment\n')
            elseif isnumeric(varargin{1}) && ndims(varargin{1}) == 3
                obj.origImage = median(varargin{1},3); %median intensity projection
                fprintf('Getting median intensity projection from supplied stack\n')
            elseif ischar(varargin{1})
                fname = varargin{1};
                if strcmp(fname,'demo')
                    % Make a testing image
                    n=250;
                    p=peaks(n);
                    obj.origImage = repmat(p,2,2);
                    obj.origImage(1:n,1:n) = p+rot90(p,2);
                    obj.origImage(n+1:end,n+1:end) = p-rot90(p,1)+flipud(p);
                elseif ischar(fname) && exist(fname,'file')
                    fprintf('Loading %s\n', fname)
                    obj.origImage = median(mhd_read(fname),3);

                    %Can we get the number of microns per pixel?
                    tok= regexp(fname,'(\d+)_(\d+)_(\d+)\.[mr]','tokens');
                    if ~isempty(tok)
                        n=cellfun(@str2num,tok{1});
                        if n(1) == n(2)
                            obj.micsPerPixel = n(1);
                            fprintf('Setting microns per pixel to %d\n', obj.micsPerPixel)
                        end
                    end %~isempty(tok)
                else
                    fprintf('Can not find file %s. Quitting\n', fname);
                    obj.delete
                    return
                end
            else

                fprintf('Please supply suitable input\n')
                obj.delete
                return

            end

            %Build the main GUI
            delete(findobj('Tag',obj.mainGUIname)) %Ensure we don't open duplicates

            obj.hMain = figure;
            obj.hMain.Tag = obj.mainGUIname;
            obj.hMain.CloseRequestFcn = @obj.figClose; %Closing figure deletes object
            obj.hMain.MenuBar = 'none';
            obj.hMain.ToolBar = 'none';
            obj.hMain.Resize = 'off';
            obj.hMain.Name = 'StitchIt Sample Splitter';
            obj.hMain.Position(4)=300;
            obj.hMain.HandleVisibility='off'; %Stops other stuff plotting into it
            mPos = get(0,'MonitorPositions');
            obj.hMain.Position(2)=mPos(4) - obj.hMain.Position(4) - 60;   



            % Add buttons
            obj.hButton_drawBoxAddROI = uicontrol('Style', 'PushButton', ...
                'Units', 'Pixels', ...
                'Position', [10,10,80,35], 'String', 'Add ROI', ...
                'ToolTip', 'Select a ROI', ...
                'Callback', @obj.areaSelector,...
                'Parent', obj.hMain);

            obj.hButton_deleteROI = uicontrol('Style', 'PushButton', ...
                'Units', 'Pixels', ...
                'Enable','off', ...
                'Position', [90,10,120,35], 'String', 'Delete ROI', ...
                'ToolTip', 'Delete a ROI', ...
                'Callback', @obj.deleteROI,...
                'Parent', obj.hMain);

            obj.hButton_autoFind = uicontrol('Style', 'PushButton', ...
                'Units', 'Pixels', ...
                'Enable','on', ...
                'Position', [210,10,130,35], 'String', 'Auto Find Brains', ...
                'ToolTip', 'Automatically draw ROIs around brains', ...
                'Callback', @obj.autoFindBrainsInLoadedImage,...
                'Parent', obj.hMain);

            % Add the uitable which will contain ROI info
            obj.hDataTable = uitable('Parent', obj.hMain, ...
                'Position', [25 50 500 225], ...
                'CellSelectionCallback', @obj.tableHighlightCallback, ...
                'CellEditCallback', @obj.tableEditCallback, ...
                'ColumnName', {'x','y','cols','rows','Rot','ROI Name'}, ...
                'ColumnWidth', {40,40,40,40,40,260},...
                'ColumnEditable', [false, false, false, false, true, true]);

            obj.listeners{end+1} = addlistener(obj.hDataTable, 'Data', 'PostSet', @obj.tableModifiedCallback);


            % Display the loaded image in a new window
            obj.openOrigView

            
        end % sampleSplitter (constructor)


        function delete(obj)
            cellfun(@delete,obj.listeners)

            delete(obj.hOrigView)
            delete(obj.hPreview)
            delete(obj.hMain)
        end % destructor


    end % methods


    methods (Hidden)
        % The following are short hidden callback functions

        function figClose(obj,~,~)
            % Figure close function callback: figures are destroyed in the destructor
            obj.delete %class destructor
        end % figClose


        function areaSelector(obj,~,~)
            % Callback function of hButton_drawBoxAddROI
            % Draws box and uses this to add a ROI
            h = imrect(obj.origViewImAxes);

            obj.lastDrawnBox = round(wait(h));
            delete(h)
            za = obj.lastDrawnBox;

            obj.addROI(za)

        end % Close areaSelector


        function deleteROI(obj,~,~)
            % hButton_deleteROI callback
            % Deletes the current selected row
            if isempty(obj.selectedRow)
                return
            end

            % Delete stuff
            fprintf('Deleting ROI: %s\n', obj.hDataTable.Data{obj.selectedRow,6})

            obj.hDataTable.Data(obj.selectedRow,:) = [];
            % Plotted ROI is deleted automatically by obj.updatePlottedBoxes which runs
            % via the listener callback obj.tableModifiedCallback

            if length(obj.hBox)<1
                obj.hButton_deleteROI.Enable='Off';
            end
        end % deleteROI


        function autoFindBrainsInLoadedImage(obj,~,~)
            % hButton_autoFind callback
            % Uses +sampleSplitter.autofindBrains to automaticall identify brains in the 
            % currently loaded image then adds these ROIs

            % Run the algorthm 
            ROIs = stitchit.sampleSplitter.autofindBrains(obj.origImage,obj.micsPerPixel);

            if isempty(ROIs)
                fprintf('Oh No! No brains found by +sampleSplitter.autofindBrains.\n')
                return
            end

            % Delete existing ROIs
            for ii=1:size(obj.hDataTable.Data,1)
                obj.selectedRow=1;
                obj.deleteROI
            end

            % Add our ROIs
            for ii=1:length(ROIs)
                fprintf('Adding ROI %d\n', ii)
                obj.addROI(ROIs{ii})
            end

        end % autoFindBrainsInLoadedImage


        function tableHighlightCallback(obj,src,evt)
            % This callback runs when a new table cell is highlighted
            % It highlights the ROI associated with the selected row
            if isempty(evt.Indices)
                return
            end
            obj.selectedRow = evt.Indices(1);

            % Highlight the correct box
            if ~isempty(obj.hBox)
                set([obj.hBox],'color','c','LineWidth',1) 
                set(obj.hBox(obj.selectedRow), 'Color','r','LineWidth',2);
            end

            % Show this ROI in window
            coords = cell2mat(obj.hDataTable.Data(obj.selectedRow ,1:4));
            rotQuantity = cell2mat(obj.hDataTable.Data(obj.selectedRow ,5));
            obj.openPreviewView(coords,rotQuantity); %Update the small preview
        end % tableHighlightCallback


        function tableEditCallback(obj,src,evt)
            % This callback runs when an edit is made to the table. We use it to 
            % rotate the ROI image if needed.

            if evt.Indices(2) ~= 5 %Then we didn't edit the rot field
                return
            end

            obj.tableHighlightCallback(src,evt);
        end % tableEditCallback


        function tableModifiedCallback(obj,src,evt)
            % This callback runs when the table is modified programatically
            if isempty(obj.selectedRow) || isempty(obj.hDataTable.Data)
                return
            end
            coords = cell2mat(obj.hDataTable.Data(obj.selectedRow ,1:4));
            rotQuantity = obj.hDataTable.Data{obj.selectedRow,5};
            obj.openPreviewView(coords,rotQuantity);

            obj.updatePlottedBoxes

        end % tableEditCallback

    end % hidden methods

end % sampleSplitter