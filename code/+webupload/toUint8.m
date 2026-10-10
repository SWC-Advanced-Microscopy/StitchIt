function out = toUint8(img)
    % Convert a gray (HxW) or RGB (HxWx3) numeric image to rounded uint8
    %
    % function out = webupload.toUint8(img)
    %
    % Purpose
    % Pure (no I/O). The image must be at least 2x2: vectors and scalars are not images.
    % Classes: uint8, uint16, int16, single, double; others error.
    %
    % Default mapping
    %   uint8          - used as is.
    %   uint16, int16  - autoscaled to [0 max(img(:))] so 11-14 bit camera data is not
    %                    near-black. Negatives clamp to 0 and an all-zero (or
    %                    all-negative) image maps to black.
    %   single, double - must be finite and within [0,1]; mapped to 0-255.
    %
    % CAVEAT: autoscaling is per image. One hot pixel darkens a whole frame, a
    % uniformly dim frame is stretched to white, and brightness therefore varies
    % between frames. For comparable brightness across a series, scale the images to
    % uint8 (or [0,1]) before calling, with one fixed range such as [0 4095] for 12-bit data.
    %
    % Inputs
    % img   - Numeric HxW or HxWx3 image.
    %
    % Outputs
    % out - uint8 image the same size as img.
    %
    % See also: webupload.stageFiles

    if ~isnumeric(img)
        error('webupload:toUint8:badImage', ...
            'Image must be numeric; got class "%s".', class(img))
    end

    validDims = (ndims(img)==2 || (ndims(img)==3 && size(img,3)==3)) ...
                && size(img,1)>=2 && size(img,2)>=2;
    if ~validDims
        error('webupload:toUint8:badImage', ...
            'Image must be at least 2x2, HxW or HxWx3; got size [%s].', num2str(size(img)))
    end
    if ~ismember(class(img),{'uint8','uint16','int16','single','double'})
        error('webupload:toUint8:badImage', 'Unsupported image class "%s".', class(img))
    end

    x = double(img);
    if isfloat(img) && any(~isfinite(x(:)))
        error('webupload:toUint8:badImage', 'Floating-point image contains NaN or Inf.')
    end

    % set a range for the conversion to uint8
    range = defaultRange(img,x);

    scaled = (x-range(1)) / (range(2)-range(1));
    out = uint8(round(255 * min(max(scaled,0),1)));
end % toUint8


function range = defaultRange(img,x)
    % Class-dependent [lo hi] used when the caller gives no range
    %
    % function range = webupload.toUint8>defaultRange(img,x)
    %
    % Purpose
    % The mappings are described in toUint8. For uint16 and int16 the upper limit is the
    % image maximum, but at least 1 so that an all-zero image does not divide by zero.
    %
    % Inputs
    % img - The original image. Only its class is used.
    % x   - The same image converted to double.
    %
    % Outputs
    % range - [lo hi] to map to 0 and 255.
    %
    % Errors
    % 'webupload:toUint8:badImage' if a single or double image is not within [0,1].

    switch class(img)
        case 'uint8'
            range = [0 255];
        case {'uint16','int16'}
            range = [0 max(max(x(:)),1)]; % max 0 would divide by zero
        otherwise % single, double
            if min(x(:))<0 || max(x(:))>1
                error('webupload:toUint8:badImage', ...
                    'Floating-point images must lie within [0,1] (or pass a range).')
            end
            range = [0 1];
    end %switch
end % defaultRange
