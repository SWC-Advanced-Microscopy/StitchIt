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
    % - run stitchit.sampleSplitter without input arguments. This will search for
    %   downsampled data in downsampled_stacks/025_micron and load it. If this is
    %   missing you will need to either make it or supply an input argument (see below)
    % - GUI appears with max intensity projection of brains.
    % - Hit "Auto Find Brains" to draw boxes around brains. (Disabled currently because it
    %   plays badly with BakingTray autoROI brains.
    % - If boxes are too big or wrong, select their row in the table and delete.
    %   Highlighted table rows are associated with red boundary in image.
    % - Hit "Add" to draw your own box.
    % - Once happy with boxses, name the samples using the last column. Avoid
    %   weird characters (although the GUI should replace these anyway).
    % - Once happy, hit "Apply ROIs to stack". There is a confirmation.
    % - ROIs are applied with progress messages on console
    %
    % Advanced use: remote without GUI
    % - Download the downsampled data directory stack and recipe file to a local
    %   directory on your PC. Then S=stitchit.sampleSplitter as above
    % - Go through all the above but don't apply the ROIs
    % - Run "myParams = S.returnROIparams"
    % - Save that as a .mat file. e.g. save myParams myParams
    % - scp that to the remote machine with the data and load it into a local
    %   MATLAB instance on that machine.
    % - cd to the data directory (if not there already) and run:
    %   stitchit.sampleSplitter.cropStitchedSections(myParams)
    % - This will initiate the process on the remote machine.
    %
    % CLEANING UP
    % Once finishes, you should delete original data in the trash directory as needed.
    %
    %
    % Optional input arguments:
    % First argument
    %    a) Path to downsampled stack of this sample
    %    b) Loaded image stack from (a)
    %    c) A 2D image that is the median or max intensity projection of that stack
    %
    % Second arguments
    %   The second optional input argument defines the number of microns per pixel.
    %   If missing, this is either "25" or, if available, derived from the MHD name.
    %
    %
    % EXAMPLES
    % 1. Loads a 25 micron downsampled stack and works with that.
    % >> stitchit.sampleSplitter
    % 2. User defines a 25 micron downsampled stack.
    % >> stitchit.sampleSplitter('downsampled_stacks/025_micron/ds_xyz_123_25_25_ch02_green.tif' )
    %
    %
    % Rob Campbell, SWC, 2019


    properties
        imStack             % The 3D stack that was loaded and used for the max projection
        origImage           % The image upon which we draw ROIs
        splitBrainParams    % A structure containing the ROIs and their orientations
        micsPerPixel = 25   % scale of the downsampled image fed into this class
        stitchedDataInfo
    end % properties

    properties (Hidden)
        hMain       % handle to main figure window containing the controls
        hOrigView   % handle to the window that displays the image for segmenting
        hPreview    % handle to the preview window showing what the segmented brain will look like

        hButton_drawBoxAddROI
        hButton_deleteROI
        hButton_autoFind
        hButton_previewROI
        hButton_applyROIs
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
            % first arg is an MHD file name (recomended), an image stack, or max intensity projection.
            % Avoid mean intensity projections, you will underestimate brain size.
            % second arg (optional) is the number of microns per pixel. If missing,
            % 50, unless it can be extracted from the MHD file fname. This valyue
            % is stored in sampleSplitter.micsPerPixel

            % First arg is an MHD file name, stack, or max/median projection.
            % Second arg (optional) is the number of microns per pixel. If missing,
            % 50, unless it can be extracted from the MHD file fname. This value
            % is stored in sampleSplitter.micsPerPixel

            %If an instance of sampleSplitter already exists then delete it
            t=evalin('base','who');
            for ii=1:length(t)
                tClasss = evalin('base',sprintf('class(%s)', t{ii} ));
                if strcmp(tClasss,'stitchit.sampleSplitter')
                    evalin('base', sprintf('delete(%s);clear(''%s'')', t{ii},t{ii}) )
                end
            end

            if isempty(varargin)
              %Look for an MHD file
              d=dir(sprintf('downsampled_stacks/%03d_micron/*.mhd',obj.micsPerPixel));
              %If that fails search for a tiff stack
              if isempty(d)
                d=dir(sprintf('downsampled_stacks/%03d_micron/*.tif',obj.micsPerPixel));
              end

              if isempty(d)
                % Warn user if there is no stitched data in the directory
                s=findStitchedData;

                msg = sprintf(['Could not find %d micron downsampled stack provide a downsampled ',...
                                'MHD or tiff stack filename, a stack, or an intensity projection\n'], ...
                                obj.micsPerPixel);
                fprintf(msg)
                if isempty(s)
                    msg = [msg,'STITCHING SEEMS TO HAVE FAILED: see command line for suggestions'];
                end
                msg = [msg,'See command line for suggestions'];
                warndlg(msg)

                if isempty(s)
                    % No stitched data
                    fprintf('\n -> Either the stitching did not start or there was an error running "stitchAllChannels; downsampleAllChannels" <-\n')
                else
                    % There are stitched data but maybe no downsampled data because stitching failed
                    fprintf('\n -> Either the downsampling did not start or the stitching failed. Try running "stitchAllChannels; downsampleAllChannels" <-\n')
                end
                obj.delete
                return
              end
              %Otherwise it's auto-found and we load all available stacks
              varargin{1} = cellfun(@(x) fullfile(d(end).folder,x),{d.name},'UniformOutput',false);
            end

            if isnumeric(varargin{1}) && ndims(varargin{1}) == 2
                obj.origImage = varargin{1};
                fprintf('Assigning input as image to segment\n')
            elseif isnumeric(varargin{1}) && ndims(varargin{1}) == 3
                obj.origImage = median(varargin{1},3); %median intensity projection
                fprintf('Getting median intensity projection from supplied stack\n')
            elseif ischar(varargin{1}) || iscell(varargin{1})
                fname = varargin{1};
                if strcmp(fname,'demo')
                    % Make a testing image
                    n=250;
                    p=peaks(n);
                    obj.origImage = repmat(p,2,2);
                    obj.origImage(1:n,1:n) = p+rot90(p,2);
                    obj.origImage(n+1:end,n+1:end) = p-rot90(p,1)+flipud(p);
                elseif ischar(fname) && exist(fname,'file') || iscell(fname)
                    loadEvery = -4;
                    if isstr(fname)
                        fprintf('Loading %s\n', fname)
                        im = stitchit.tools.loadTiffStack(fname,'frames',loadEvery);
                    elseif iscell(fname)
                        for ii=1:length(fname)
                            fprintf('loading %s\n', fname{ii})
                            im(:,:,:,ii) = stitchit.tools.loadTiffStack(fname{ii},'frames',loadEvery);
                        end %for ii
                        im = mean(im,4);
                    end %if isstr

                    obj.imStack = im;
                    obj.origImage = stitchit.sampleSplitter.filterAndProjectStack(im);

                    fprintf('Image is of size %d x %d\n', ...
                            size(obj.origImage,1), size(obj.origImage,2));

                    %Can we get the number of microns per pixel?
                    if iscell(fname)
                        fname = fname{1};
                    end

                    tok= regexp(fname,'(\d+)_(\d+)_ch0','tokens');
                    if ~isempty(tok)
                        n=cellfun(@str2num,tok{1});
                        if n(1) == n(2)
                            obj.micsPerPixel = n(1);
                            fprintf('Setting microns per pixel to %d\n', obj.micsPerPixel)
                        end
                    else
                        [~,tFname]=fileparts(fname);
                        msg = sprintf('FAILED TO FIND PIXEL SIZE IN FILE NAME "%s"', tFname);
                        fprintf(msg)
                        warndlg(msg)
                        obj.delete
                        return
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
                'ToolTip', 'Add a new ROI (draw box then double-click)', ...
                'Callback', @obj.areaSelector,...
                'Parent', obj.hMain);

            obj.hButton_deleteROI = uicontrol('Style', 'PushButton', ...
                'Units', 'Pixels', ...
                'Enable','off', ...
                'Position', [90,10,80,35], 'String', 'Delete ROI', ...
                'ToolTip', 'Delete selected ROI', ...
                'Callback', @obj.deleteROI,...
                'Parent', obj.hMain);

            obj.hButton_autoFind = uicontrol('Style', 'PushButton', ...
                'Units', 'Pixels', ...
                'Position', [170,10,110,35], 'String', 'Auto Find Brains', ...
                'ToolTip', 'Automatically draw ROIs around brains', ...
                'Callback', @obj.autoFindBrainsInLoadedImage,...
                'Enable', 'Off', ...
                'Parent', obj.hMain);

            obj.hButton_previewROI = uicontrol('Style', 'PushButton', ...
                'Units', 'Pixels', ...
                'Enable','off', ...
                'Position', [280,10,80,35], 'String', 'Preview', ...
                'ToolTip', 'Crop a stitched section TIFF from disk and show a preview on screen', ...
                'Callback', @obj.showPreview,...
                'Parent', obj.hMain);

            obj.hButton_applyROIs = uicontrol('Style', 'PushButton', ...
                'Units', 'Pixels', ...
                'Enable','off', ...
                'Position', [360,10,80,35], 'String', 'Apply ROIs', ...
                'ToolTip', 'Apply ROIs to stack', ...
                'Callback', @obj.applyROIsToStitchedData,...
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

            obj.stitchedDataInfo=findStitchedData;
            if isempty(obj.stitchedDataInfo)
                fprintf('No stitched data present. You can draw ROIs only but not apply them.\n')
                return
            end

        end % sampleSplitter (constructor)


        function delete(obj)
            cellfun(@delete,obj.listeners)

            delete(obj.hOrigView)
            delete(obj.hPreview)
            delete(obj.hMain)
        end % destructor


    end % methods



    methods
        % The following are short methods or callbacks that we might want exposed to the user
        function applyROIsToStitchedData(obj,~,~)
            % hButton_applyROIs callback
            % Split up or crop sample based on the current ROIs. Then closes the GUI
            % once the task is complete.
            q = questdlg(sprintf('Really apply these ROIs?'));
            if strcmp(q,'Yes')
                stitchit.sampleSplitter.cropStitchedSections(obj.returnROIparams);
            end
            obj.figClose
        end % applyROIsToStitchedData


        function autoFindBrainsInLoadedImage(obj,~,~)
            % hButton_autoFind callback
            % Uses +sampleSplitter.autofindBrains to automaticall identify brains in the
            % currently loaded image then adds these ROIs

            % Run the algorithm
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

    end



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
            rowToDelete = obj.selectedRow;
            fprintf('Deleting ROI: %s at row %d\n', obj.hDataTable.Data{obj.selectedRow,6}, rowToDelete)

            % Prepare for deletion by ensuring nothing can have an invalid value
            % before the row is deleted
            if size(obj.hDataTable.Data,1)==1
                % Since after deletion the table will by empty
                obj.hButton_deleteROI.Enable='Off';
                obj.hButton_previewROI.Enable='Off';
                obj.hButton_applyROIs.Enable='Off';
                obj.selectedRow=[];
            else
                % Just set the first ROI
                obj.selectedRow=1;
            end

            % TODO: it's not deleting the row I would expect it to
            obj.hDataTable.Data(rowToDelete,:) = [];
            % Plotted ROI is deleted automatically by obj.updatePlottedBoxes which runs
            % via the listener callback obj.tableModifiedCallback

        end % deleteROI

        function showPreview(obj,~,~)
            % hButton_previewROI callback
            obj.previewROIs
        end


        function tableHighlightCallback(obj,~,evt)
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

            % If the rot field was edited, we  check that the valu is reasonable
            % before proceeding
            if isnan(evt.NewData)
                % Then it's not a number, so replace with the previous value
                src.Data{evt.Indices(1),evt.Indices(2)} = evt.PreviousData;
                return
            end

            % Ensure it's an integer
            if mod(evt.NewData,1)>0
                src.Data{evt.Indices(1),evt.Indices(2)} = evt.PreviousData;
                return
            end

            % Ensure it's between -2 and +2
            if evt.NewData<-2 || evt.NewData>2
                src.Data{evt.Indices(1),evt.Indices(2)} = evt.PreviousData;
                return
            end


            obj.tableHighlightCallback(src,evt);
        end % tableEditCallback


        function tableModifiedCallback(obj,~,~)
            % This callback runs when the table is modified programatically


            if isempty(obj.hDataTable.Data)
                % To ensure all plotted boxes are deleted
                obj.updatePlottedBoxes
                return
            end

            if isempty(obj.selectedRow)
                return
            end

            coords = cell2mat(obj.hDataTable.Data(obj.selectedRow ,1:4));
            rotQuantity = obj.hDataTable.Data{obj.selectedRow,5};
            obj.openPreviewView(coords,rotQuantity);

            obj.updatePlottedBoxes

        end % tableEditCallback

    end % hidden methods

end % sampleSplitter
