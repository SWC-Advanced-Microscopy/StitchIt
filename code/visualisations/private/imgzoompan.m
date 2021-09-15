function imgzoompan(varargin)
% imgzoompan provides instant mouse zoom and pan
%
% function imgzoompan(varargin)
%
%% Purpose
% This function provides instant mouse zoom (mouse wheel) and pan (mouse drag) capabilities 
% to figures, designed for displaying 2D images that require lots of drag & zoom. For more
% details see README file. NOTE: this function works only on the current axes of the figure
% window to which it is targetted. By default this is the last plotted axis. 
%
% 
%% Inputs (optional param/value pairs)
% 'hFig' Handle to a figure window to which we will target imgzoompan
%
% The following relate to zoom config
% * 'Magnify' General magnitication factor. 1.0 or greater (default: 1.1). A value of 2.0 
%             solves the zoom & pan deformations caused by MATLAB's embedded image resize method.
% * 'XMagnify'        Magnification factor of X axis (default: 1.0).
% * 'YMagnify'        Magnification factor of Y axis (default: 1.0).
% * 'ChangeMagnify'.  Relative increase of the magnification factor. 1.0 or greater (default: 1.1).
% * 'IncreaseChange'  Relative increase in the ChangeMagnify factor. 1.0 or greater (default: 1.1).
% * 'MinValue' Sets the minimum value for Magnify, ChangeMagnify and IncreaseChange (default: 1.1).
% * 'MaxZoomScrollCount' Maximum number of scroll zoom-in steps; might need adjustements depending 
%                        on your image dimensions & Magnify value (default: 30).
%
%
%% Outputs
%  none
%
% 
%% ACKNOWLEDGEMENTS:
%
% *) Hugo Eyherabide (Hugo.Eyherabide@cs.helsinki.fi) as this project uses his code
%    (FileExchange: zoom_wheel) as reference for zooming functionality.
% *) E. Meade Spratley for his mouse panning example (FileExchange: MousePanningExample).
% *) Alex Burden for his technical and emotional support.
%
% Send code updates, bug reports and comments to: Dany Cabrera (dcabrera@uvic.ca)
% Please visit https://github.com/danyalejandro/imgzoompan (or check the README.md text file) for
% full instructions and examples on how to use this plugin.
%
%% Copyright (c) 2018, Dany Alejandro Cabrera Vargas, University of Victoria, Canada,
% published under BSD license (http://www.opensource.org/licenses/bsd-license.php).


% Do not start if there are no open figure windows
if isempty(findobj('type','figure'))
    fprintf('%s -- finds no open figure windows. Quitting.\n', mfilename)
    return
end


% Legacy call structure saw the first input argument being a handle to a figure. 
% Catch this and convert to new call structure where the figure is always an optional argument
if length(varargin)>0 && isa(varargin{1},'matlab.ui.Figure')
    fprintf('CONVERTING CALL\n')
    varargin = ['hFig',varargin];
end

% Parse configuration options
p = inputParser;
p.CaseSensitive = false;

% For targetting to a particular figure window
p.addParamValue('hFig', [], @(x) isa(x,'matlab.ui.Figure'));

% Zoom configuration options
p.addParamValue('Magnify', 1.1, @isnumeric);
p.addParamValue('XMagnify', 1.0, @isnumeric);
p.addParamValue('YMagnify', 1.0, @isnumeric);
p.addParamValue('ChangeMagnify', 1.1, @isnumeric);
p.addParamValue('IncreaseChange', 1.1, @isnumeric);
p.addParamValue('MinValue', 1.1, @isnumeric);
p.addParamValue('MaxZoomScrollCount', 30, @isnumeric);

% Mouse options and callbacks
p.addParamValue('PanMouseButton', 2, @isnumeric);
p.addParamValue('ResetMouseButton', 3, @isnumeric);
p.addParamValue('ButtonDownFcn',  @(~,~) 0);
p.addParamValue('ButtonUpFcn', @(~,~) 0) ;

% Parse & Sanitize options
parse(p, varargin{:});
opt = p.Results;

if opt.Magnify<opt.MinValue
    opt.Magnify=opt.MinValue;
end
if opt.ChangeMagnify<opt.MinValue
    opt.ChangeMagnify=opt.MinValue;
end
if opt.IncreaseChange<opt.MinValue
    opt.IncreaseChange=opt.MinValue;
end

hFig = opt.hFig;
if isempty(hFig)
    hFig=gcf;
end
opt = rmfield(opt,'hFig'); %Won't need this again


% Place the settings and temporary variable into the figure's UserData property
hFig.UserData.zoompan = opt;
hFig.UserData.zoompan.zoomScrollCount = 0;
hFig.UserData.zoompan.origH=[];
hFig.UserData.zoompan.origXLim=[];
hFig.UserData.zoompan.origYLim=[];

% Set up callback functions
set(hFig, 'WindowScrollWheelFcn', @zoom_fcn);
set(hFig, 'WindowButtonDownFcn', @down_fcn);
set(hFig, 'WindowButtonUpFcn', @up_fcn);





% -------------------------------
% Start of callback functions 


function zoom_fcn(src, evt)
    % This callback function is called when the mouse scroll wheel event fires. 
    % The callback is used to manage figure zooming

    scrollChange = evt.VerticalScrollCount; % -1: zoomIn, 1: zoomOut
    zpSet = src.UserData.zoompan;


    if ((zpSet.zoomScrollCount - scrollChange) <= zpSet.MaxZoomScrollCount)
        axish = gca;

        %Get the width and height of the image
        [ImgHeight,ImgWidth]=getWidthHeight(axish);

        if isempty(src.UserData.zoompan.origH) || axish ~= src.UserData.zoompan.origH
            src.UserData.zoompan.origH = axish;
            src.UserData.zoompan.origXLim = axish.XLim;
            src.UserData.zoompan.origYLim = axish.YLim;
        end

        % calculate the new XLim and YLim
        cpaxes = mean(axish.CurrentPoint);
        newXLim = (axish.XLim - cpaxes(1)) * (zpSet.Magnify * zpSet.XMagnify)^scrollChange + cpaxes(1);
        newYLim = (axish.YLim - cpaxes(2)) * (zpSet.Magnify * zpSet.YMagnify)^scrollChange + cpaxes(2);

        newXLim = floor(newXLim);
        newYLim = floor(newYLim);

        if diff(newYLim)==0 || diff(newXLim)==0
            % Avoid zooming in to a single point
            return
        end

        if (newXLim(1) >= 0 && newXLim(2) <= ImgWidth && newYLim(1) >= 0 && newYLim(2) <= ImgHeight)
            axish.XLim = newXLim;
            axish.YLim = newYLim;
            src.UserData.zoompan.zoomScrollCount = src.UserData.zoompan.zoomScrollCount - scrollChange;
        else
            if ~isempty(zpSet.origXLim)
                axish.XLim = zpSet.origXLim;
            end
            if ~isempty(zpSet.origYLim)
                axish.YLim = zpSet.origYLim;
            end
            src.UserData.zoompan.zoomScrollCount = 0;
        end

    else
        % TODO: can't ever have run since newXLim would never be defined. Comment out for now. 
        % For some reason the new updates (ROB) cause the odd entry into here. 
        %axish.XLim = newXLim;
        %axish.YLim = newYLim;
        %src.UserData.zoompan.zoomScrollCount = src.UserData.zoompan.zoomScrollCount - scrollChange;
    end
    %fprintf('XLim: [%.3f, %.3f], YLim: [%.3f, %.3f]\n', axish.XLim(1), axish.XLim(2), axish.YLim(1), axish.YLim(2));


function down_fcn(src, evt)
    % This callback function is called when the mouse button goes down. 
    % The callback is used to manage figure panning.

    zpSet = src.UserData.zoompan;
    zpSet.ButtonDownFcn(src, evt); % First, run callback from options


    clickType = evt.Source.SelectionType;

    % Panning action
    panBt = zpSet.PanMouseButton;
    if (panBt > 0)
        if (panBt == 1 && strcmp(clickType, 'normal')) || ...
            (panBt == 2 && strcmp(clickType, 'alt')) || ...
            (panBt == 3 && strcmp(clickType, 'extend'))

            guiArea = hittest(src);
            parentAxes = ancestor(guiArea,'axes');

            % if the mouse is over the desired axis, trigger the pan fcn
            if ~isempty(parentAxes)
                startPan(parentAxes)
            else
                setptr(evt.Source,'forbidden')
            end
        end
    end


function up_fcn(src, evt)
    % This callback function is called when the mouse button goes up. 
    % The callback is used to manage figure panning.

    zpSet = src.UserData.zoompan;
    zpSet.ButtonUpFcn(src, evt); % First, run callback from options

    % Reset action
    clickType = evt.Source.SelectionType;
    resBt = zpSet.ResetMouseButton;
    if (resBt > 0 && ~isempty(zpSet.origXLim))
        if (resBt == 1 && strcmp(clickType, 'normal')) || ...
            (resBt == 2 && strcmp(clickType, 'alt')) || ...
            (resBt == 3 && strcmp(clickType, 'extend'))

            guiArea = hittest(src);
            parentAxes = ancestor(guiArea,'axes');
            parentAxes.XLim=zpSet.origXLim;
            parentAxes.YLim=zpSet.origYLim;
        end
    end

    set(gcbf,'WindowButtonMotionFcn',[]);
    setptr(gcbf,'arrow');




% -------------------------------
% Start of helper functions for axis panning

function startPan(hAx)
    % Call this Fcn in your 'WindowButtonDownFcn'
    % Take in desired Axis to pan
    % Get seed points & assign the Panning Fcn to top level Fig
    hFig = ancestor(hAx, 'Figure', 'toplevel');   % Parent Fig

    seedPt = get(hAx, 'CurrentPoint'); % Get init mouse position
    seedPt = seedPt(1, :); % Keep only 1st point

    % Temporarily stop 'auto resizing'
    hAx.XLimMode = 'manual'; 
    hAx.YLimMode = 'manual';

    set(hFig,'WindowButtonMotionFcn',{@panningFcn,hAx,seedPt});
    setptr(hFig, 'hand'); % Assign 'Panning' cursor



function panningFcn(src,~,hAx,seedPt)
    % Controls the real-time panning on the desired axis
    zpSet = src.UserData.zoompan;
    % Get current mouse position
    currPt = get(hAx,'CurrentPoint');
    [ImgHeight,ImgWidth]=getWidthHeight(hAx);

    % Current Limits [absolute vals]
    XLim = hAx.XLim;
    YLim = hAx.YLim;

    % Original (seed) and Current mouse positions [relative (%) to axes]
    x_seed = (seedPt(1)-XLim(1))/(XLim(2)-XLim(1));
    y_seed = (seedPt(2)-YLim(1))/(YLim(2)-YLim(1));

    x_curr = (currPt(1,1)-XLim(1))/(XLim(2)-XLim(1));
    y_curr = (currPt(1,2)-YLim(1))/(YLim(2)-YLim(1));

    % Change in mouse position [delta relative (%) to axes]
    deltaX = x_curr-x_seed;
    deltaY = y_curr-y_seed;

    % Calculate new axis limits based on mouse position change
    newXLims(1) = -deltaX*diff(XLim)+XLim(1);
    newXLims(2) = newXLims(1)+diff(XLim);

    newYLims(1) = -deltaY*diff(YLim)+YLim(1);
    newYLims(2) = newYLims(1)+diff(YLim);

    % MATLAB lack of anti-aliasing deforms the image if XLims & YLims are not integers
    newXLims = round(newXLims);
    newYLims = round(newYLims);

    % Update Axes limits
    if (newXLims(1) > 0.0 && newXLims(2) < ImgWidth)
        set(hAx,'Xlim',newXLims);
    end
    if (newYLims(1) > 0.0 && newYLims(2) < ImgHeight)
        set(hAx,'Ylim',newYLims);
    end

function [ImgHeight,ImgWidth]=getWidthHeight(axish)
    % Find the width and height of the first child image in the axes
    C=axish.Children;
    for ii=1:length(C)
        if isa(C(ii),'matlab.graphics.primitive.Image')
            [ImgHeight, ImgWidth,~] = size(C(ii).CData);
            break
        end
    end
