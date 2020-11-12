function ROIS=returnROIparams(obj)
    % Returns the current ROI parameters as a structure 
    %
    % function ROIS=returnROIparams(obj)
    %
    %


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
        ROIS(ii).areaProportion = prod(ROIS(ii).ROI(3:4)) / prod(size(obj.origImage));
    end

    % If this is an auto-ROI acquisition we assess how well the acquisition performed
    % and save the stats related to this to the structure
    m=readMetaData2Stitchit;
    ROIS(1).autoROIperformance=[];
    if strcmp(m.mosaic.scanmode,'tiled: auto-ROI')
        ROIS(1).autoROIperformance = obj.return_autoROI_performance(ROIS);
    end
end
