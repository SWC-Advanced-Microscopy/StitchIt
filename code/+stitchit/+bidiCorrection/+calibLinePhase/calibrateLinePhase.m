function newPhase = calibrateLinePhase(im, metaData)

    linePhase = metaData.linePhase;
    ff_s = metaData.fillFractionSpatial;
    ff_t = metaData.fillFractionTemporal;
    scannerFrequency = metaData.scannerFrequency;
    
    tf = 0;
    if ~tf
        imT = imToTimeDomain(im,ff_s,ff_t);
    else
        imT = im;
    end

    im_odd  = imT(:,1:2:end);
    im_even = imT(:,2:2:end);

    % first brute force search to find minimum
    offsets_rad = linspace(-1,1,31)*pi/8;
    ds = arrayfun(@(offset_rad)imDifference(im_odd,im_even,ff_s,ff_t,offset_rad),offsets_rad);
    [d,idx] = min(ds);
    offset_rad = offsets_rad(idx);

    % secondary brute force search to refine minimum
    offsets_rad = offset_rad+linspace(-1,1,51)*diff(offsets_rad(1:2));
    ds = arrayfun(@(offset_rad)imDifference(im_odd,im_even,ff_s,ff_t,offset_rad),offsets_rad);
    [d,idx] = min(ds);
    offset_rad = offsets_rad(idx);

    offsetLinePhase = offset_rad /(2*pi)/scannerFrequency;
    linePhase =  linePhase - offsetLinePhase;

    newPhase = linePhase;

    %%% Local Functions
    function [d,im] = imDifference(im_odd, im_even, ff_s, ff_t, offset_rad)
        im_odd  = imToSpatialDomain(im_odd , ff_s, ff_t, offset_rad);
        im_even = imToSpatialDomain(im_even, ff_s, ff_t,-offset_rad);

        d = im_odd - im_even;
        d(isnan(d)) = []; % remove artifacts from interpolation
        d = sum(abs(d(:))) ./ numel(d); % least square difference, normalize by number of elements

        if nargout > 1
            im = cat(3,im_odd,im_even);
            im = permute(im,[1,3,2]);
            im = reshape(im,size(im,1),[]);
        end
    end

    function im = imToTimeDomain(im,ff_s,ff_t)
        nPix = size(im,1);
        xx_lin = linspace(-ff_s,ff_s,nPix);
        xx_rad = linspace(-ff_t,ff_t,nPix)*pi/2;
        xx_linq = sin(xx_rad);

        im = interp1(xx_lin,im,xx_linq,'linear',NaN);
    end

    function im = imToSpatialDomain(im,ff_s,ff_t,offset_rad)
        nPix = size(im,1);
        xx_rad = linspace(-ff_t,ff_t,nPix)*pi/2+offset_rad;
        xx_lin = linspace(-ff_s,ff_s,nPix);
        xx_radq = asin(xx_lin);

        im = interp1(xx_rad,im,xx_radq,'linear',NaN);
    end

%     function im = getImage()
%         %get image from every roi
%         roiDatas = obj.hSI.hDisplay.lastStripeData.roiData;
%         for i = numel(roiDatas):-1:1
%             im = vertcat(roiDatas{i}.imageData{:});
% 
%             if ~roiDatas{i}.transposed
%                 im = cellfun(@(imt){imt'},im);
%             end
% 
%             imData{i,1} = horzcat(im{:});
%         end
% 
%         im = horzcat(imData{:});
% 
%         nLines = size(im,2);
%         if nLines > 1024
%             im(:,1025:end) = []; % this should be enough lines for processing
%         elseif mod(nLines,2)
%             im(:,end) = []; % crop to even number of lines
%         end
% 
%         im = single(im);
%     end
end
