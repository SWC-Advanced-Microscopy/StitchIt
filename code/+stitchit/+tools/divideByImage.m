function im = divideByImage(im, template)

% Divide image (or image stack) by a template image (e.g. a mean image)
%
%  function im = divideByImage(im, template)
%
%
% Rob Campbell - Basel 2014


%Issue error if images are not the same
if size(im,1)~=size(template,1) || size(im,2)~=size(template,2)
    error('Image sizes not identical')
end


imClass=class(im);

%Convert to singles, as int division is nasty
im=single(im);
template=single(template);

reciprocalOfIntensity = ones(size(template),'single') ./ template * median(template(:));

im = bsxfun(@times, im, reciprocalOfIntensity);

im = cast(im,imClass); %return to original class
