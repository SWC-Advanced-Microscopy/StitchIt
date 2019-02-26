function OUT=getROIfromImage(im,ROIstruct)
    % Cut out a given number of ROIs from an input image given 
    % the ROI structure produced by the method stitchit.sampleSplitter.writeROIparams
    %

    OUT={};
    m=readMetaData2Stitchit;
    voxelSize = mean(m.voxelSize.X + m.voxelSize.Y)/2;
    scaleFactor = ROIstruct(1).micsPerPixel / voxelSize
    for ii=1:length(ROIstruct)
        pos = round(ROIstruct(ii).ROI * scaleFactor)
        pixelCols = pos(1) : (pos(1)+pos(3));
        pixelRows = pos(2) : (pos(2)+pos(4));

        OUT{ii} = rot90(im(pos(2) : (pos(2)+pos(4)), pos(1) : (pos(1)+pos(3))), ...
                        ROIstruct(ii).rot );

        size(OUT{ii})
        imagesc(OUT{ii})
        caxis([0,1000])
        colormap gray
        axis equal off
        drawnow
        pause
    end