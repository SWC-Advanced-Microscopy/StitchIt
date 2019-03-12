function varargout=pfigure(figID,varargin)
    % Make persistent-like figures that can be re-used across function calls
    %
    % Purpose 
    % This simple function replaces "figure" calls in a function that would
    % otherwise spawn a new figure window each time the function is re-run. 
    % Leads to more elegant than the hackish approach of adding doing things like 
    % "figure(34534)".
    %
    % Usage
    % Simply make figures in your function using the "pfigure" command instead of
    % of "figure". The same figure window will be re-used for the same *line* of code
    % each time you call the function. So you may get some extra figures if you edit
    % your code and the figure calls move lines. You can over-ride this if you wish
    % by specifying a meaningful name for your figure. e.g. "pfigure('xyplot')"
    %
    % If you have only one pfigure call in a function then you may sidestep the 
    % line changing issue by running "pfigure([])"
    %
    % If you wish to provide other input arguments e.g. "figure('color','r')" then 
    % you will have to provide an ID string as the first argument. e.g.
    % pfigure('myXYplot','color','r')
    %
    %
    % How it works
    % pfigure uses "Tag" property of the figure to find it again. Without input
    % arguments it uses dbstack to identify which function and which line was caller.
    %
    % Restrictions
    % pfigure without a defined figID does not work from the command line.
    %
    %
    % Rob Campbell - SWC 2019


    d=dbstack;
    if nargin<1 && length(d)>1
        figID = sprintf('%s%d',d(2).name,d(2).line);
    elseif nargin<1 && length(d)==1
        fprintf('\nWhen calling pfigure from the command line, please provide input argument "figID"\n\n');
        return
    elseif nargin>0 && isempty(figID)
        figID = d(2).name;
    elseif isnumeric(figID) && isscalar(figID)
        figID = num2str(figID);
    elseif ischar(figID)
        %pass
    else
        error('figID must be empty or a string')
    end




    % Search for the figure. If it does not exist, make it. If it does exist, focus 
    % it optionally return its handle
    f=findobj('Tag',figID);

    if isempty(f)
        f = figure('Tag',figID);
    else
        figure(f)

    end

    if length(varargin)>0
        set(f,varargin{:})
    end

    clf(f)

    if nargout>0
        varargout{1} = f;
    end
