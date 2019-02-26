function varargout=writeROIparams(obj,savePath)
    % Writes the current ROI parameters to structure in the current directory.
    % If a different location is desired, this can be supplied using the 
    % optional argument "savePath". Data are saved in a structure called "ROIS"
    %
    % If an output argument is requested then the data are returned as a structure
    % and are not saved to disk

    if nargin<2
        savePath=pwd;
    end

    data = obj.hDataTable.Data;

    if isempty(data)
        return
    end

    for ii=1:size(data,1)
        ROIS(ii).ROI = [data{ii,1:4}];
        ROIS(ii).rot = data{ii,5};
        ROIS(ii).name = data{ii,6};
        % Make name safe
        ROIS(ii).name = strrep(ROIS(ii).name,' ','_');
        ROIS(ii).micsPerPixel = obj.micsPerPixel;
    end


    if nargout>0
        varargout{1} = ROIS;
    else
        save(fullfile(savePath,'ROIsplitStruct.mat'), ROIS)
    end


end