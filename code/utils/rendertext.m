%by Davide Di Gloria 
%with the great contribution of Franz-Gerold Url
%
%Render RGB text over RGB or grayscale images
%
%out=rendertext(target, text, color, pos, mode1, mode2)
%
%target ... MxNx3 or MxN matrix (grayscale will be converted to RGB)
%text   ... string (NO LINE FEED SUPPORT)
%color  ... vector in the form [r g b] 0-255
%pos    ... position (r,c) 
%
%optional arguments: (default is 'ovr','left')
%mode1  ... 'ovr' to overwrite, 'bnd' to blend text over image
%mode2  ... text aligment 'left', 'mid'  or 'right'.
%
%out    ... has same size of target
%
%example:
%
%in=imread('football.jpg');
%out=rendertext(in,'OVERWRITE mode',[0 255 0], [1, 1]);
%out=rendertext(out,'BLEND mode',[255 0 255], [30, 1], 'bnd', 'left');
%out=rendertext(out,'left',[0 0 255], [101, 150], 'ovr', 'left');
%out=rendertext(out,'mid',[0 0 255], [130, 150], 'ovr', 'mid');
%out=rendertext(out,'right',[0 0 255], [160, 150], 'ovr', 'right');
%imshow(out)

function target=rendertext(target, text, color, pos, mode1, mode2,dim_img)


%Input argument error checking
if nargin < 5 | isempty(mode1)
    mode1='ovr';
end

if nargin < 6 | isempty(mode2)
    mode2='left';
end

if nargin < 6
  dim_img = size(target(:,:,1)); 
end

dim = length(size(target));
if dim == 2
  target = cat(3, target, target, target);
end


r=color(1);
g=color(2);
b=color(3);

n=numel(text);

base=uint16(1-logical(imread('chars.bmp')));
base=cat(3, base*r, base*g, base*b);


table='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890''ì!"£$%&/()=?^è+òàù,.-<\|;:_>ç°§é*@#[]{} ';


coord(2,n)=0;
for i=1:n    
  coord(:,i)= [0 find(table == text(i))-1];
end

m = floor(coord(2,:)/26);
coord(1,:) = m*20+1;
coord(2,:) = (coord(2,:)-m*26)*13+1;

overlay = uint16(zeros(20,n*13,3));
for ii=1:n
  overlay(:, (13*ii-12):(ii*13), :) = imcrop(base,[coord(2,ii) coord(1,ii) 12 19]);
end

dim = size(overlay(:,:,1));

switch mode2
  case 'mid'
    pos = pos-dim/2+1;
  case 'right'
    pos = pos-dim+1;
  case 'left'
  otherwise
    error('%s not allowed as alignment specifier. (Allowed: left, mid  or right)', mode2)
end


if sum(dim > dim_img) ~= 0
    error('The text is too long for this image.')
end 

pos = min(dim_img,pos+dim)-dim;

area_y = pos(1):(pos(1)+size(overlay,1)-1);
area_x = pos(2):(pos(2)+size(overlay,2)-1);

switch mode1
  case 'ovr'
    target(area_y, area_x,:)=overlay; 
  case 'bnd'
    area = target(area_y, area_x, :);
    area(overlay~=0) = 0;  
    target(area_y, area_x, :) = overlay + area;
  otherwise
    error('%s is a wrong overlay mode (allowed: ovr or bnd)', mode1)
end




