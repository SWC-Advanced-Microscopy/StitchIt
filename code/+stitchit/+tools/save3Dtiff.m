function save3Dtiff(imageStack,fname,options)
% Save 3-D grayscale matrix 'imageStack' as 3-D tiff 'fname'.
%
% function stitchit.tools.save3Dtiff(imageStack,fname,options)
%
% Purpose
% Save 3-D grayscale matrix 'imageStack' as a multi-page TIFF 'fname'.
% If the data are uint8 or uint16 they are saved as is. If the data are floats
% between 0 and 1, they are scaled by 65535 and saved as uint16. Other floats
% are rounded and clipped to the uint16 range. This function just uses imwrite. By default data are not compressed.
%
%
% Inputs
% imageStack - 3D image stack. uint8, uint16, or a float in the range 0 to 1
% fname - file name to which data are to be saved
% options - param/value arguments to be fed into imwrite.
%
%
%
% Rob Campbell, September 2009

if nargin<3
  options={'compression','none'};
end


% uint8 and uint16 are written as they are. Floats in the range 0 to 1 are
% scaled to the full uint16 range. Anything else is cast to uint16 (values
% are rounded and saturate at 0 and 65535).
switch class(imageStack)
    case {'uint8','uint16'}
        % nothing to do
    case {'single','double'}
        mn = min(imageStack(:));
        mx = max(imageStack(:));
        if mn>=0 && mx<=1
            imageStack = uint16(imageStack * (2^16-1));
        else
            if mn<0 || mx>2^16-1
                fprintf('%s: values outside 0 to 65535 will be clipped\n', mfilename)
            end
            imageStack = uint16(imageStack);
        end
    otherwise
        imageStack = uint16(imageStack);
end


imwrite(imageStack(:,:,1),fname,'tiff','writemode','overwrite',options{:})

for ii=2:size(imageStack,3)
  imwrite(imageStack(:,:,ii),fname,'tiff','writemode','append',options{:})
end
