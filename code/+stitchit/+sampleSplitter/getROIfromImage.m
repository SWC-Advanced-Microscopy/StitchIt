function OUT=getROIfromImage(imToCrop,imToCropMicsPerPixel,ROIstruct)
    % Cut out a given number of ROIs from an input image given 
    %
    % function OUT=getROIfromImage(imToCrop,imToCropMicsPerPixel,ROIstruct)
    %
    % Inputs
    % imToCrop - a single image to crop
    % imToCropMicsPerPixel - microns per pixel in x/y of this image
    % ROIstruct - output of the method stitchit.sampleSplitter.returnROIparams
    %
    % Outputs
    % Data are returnd as a cell array

    if isempty(imToCropMicsPerPixel)
        m=readMetaData2Stitchit;
        imToCropMicsPerPixel = mean(m.voxelSize.X + m.voxelSize.Y)/2;
        fprintf('stitchit.sampleSplitter.getROIfromImage guessing imToCrop is %0.2f mics/pixel\n',imToCropMicsPerPixel)
    end
    OUT={};

    scaleFactor = ROIstruct(1).micsPerPixel / imToCropMicsPerPixel;

    for ii=1:length(ROIstruct)
        pos = round(ROIstruct(ii).ROI * scaleFactor);

        %Confirm we are within bounds
        if pos(1)<1
            pos(1)=1;
        end
        if pos(2)<1
            pos(2)=1;
        end

        finalCol  = (pos(1)+pos(3));
        if finalCol>size(imToCrop,2)
            finalCol=size(imToCrop,2);
        end
        pixelCols = pos(1) : finalCol;

        finalRow  = (pos(2)+pos(4));
        if finalRow>size(imToCrop,1)
            finalRow=size(imToCrop,1);
        end
        pixelRows = pos(2) : finalRow;

        OUT{ii} = rot90(imToCrop(pixelRows, pixelCols),  ROIstruct(ii).rot );

    end
