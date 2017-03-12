function [p1,p2]=showVolume(stack)
%

stack = stack(1:2:end,1:2:end,1:2:end);





fprintf('pre-processing\n')
cropit=0;
if cropit
    [x,y,z,stack] = subvolume(stack,[round(size(stack,1)*0.5),nan,...
                                 round(size(stack,2)*0.5),nan,...
                                 round(size(stack,3)*0.66),nan]);
else
    [x,y,z,stack] = subvolume(stack,[1,nan,1,nan,1,nan]);
end

fprintf('doing isonormals\n')
thresh=25;
clf
p1 = patch(isosurface(x,y,z,stack, thresh),...
     'FaceColor','red','EdgeColor','none');

isonormals(x,y,z,stack,p1);

fprintf('doing isocaps\n')
p2 = patch(isocaps(x,y,z,stack, thresh),...
     'FaceColor','interp','EdgeColor','none');

view(3); 
daspect([1,1,.1])
colormap(gray(100))
camlight right; camlight left; 

set(gca,'CLim',[0,1.5E3])
axis tight equal