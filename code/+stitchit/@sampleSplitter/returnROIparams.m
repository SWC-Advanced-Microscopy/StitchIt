function ROIS=returnROIparams(obj)
    % Returns the current ROI parameters as a structure 


    data = obj.hDataTable.Data;

    if isempty(data)
        ROIS=[];
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

end