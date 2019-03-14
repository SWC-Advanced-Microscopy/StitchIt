function varargout=writeROIparams(obj,savePath)
    % Writes the current ROI parameters to structure in the current directory.
    % If a different location is desired, this can be supplied using the 
    % optional argument "savePath". Data are saved in a structure called "ROIS"
    %
    % If an output argument is requested then the data are returned as a structure
    % and are not saved to disk. See also returnROIparams. 

    if nargin<2
        savePath=pwd;
    end

    ROIS = obj.returnROIparams;

    if nargout>0
        varargout{1} = ROIS;
    else
        save(fullfile(savePath,'ROIsplitStruct.mat'), ROIS)
    end


end