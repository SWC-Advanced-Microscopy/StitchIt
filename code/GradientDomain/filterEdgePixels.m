function im=filterEdgePixels(im,mask,thresh)


%find pixels above threshold

edgePixels=im.*cast(mask,class(im));

f=find(edgePixels>thresh);

fprintf('Correcting %d edge pixels\n',length(f));


[I,J]=ind2sub(size(im),f);


aveRadius=4; %Radius over which to pool pixels for local averaging


for ii=1:length(f)

    indI = I(ii)-3:I(ii)+3;
    indJ = J(ii)-3:J(ii)+3;

    ind = [indI;indJ];

    %remove stuff near the edges of the image
    ind(:,any(ind<=3))=[];
    ind(:,ind(1,:)>=size(im,1)-3)=[];
    ind(:,ind(2,:)>=size(im,2)-3)=[];

    %Get the pixels
    tmp=im(ind(1,:),ind(2,:));
%    tmp=tmp(:);
 %   tmp(tmp>thresh)=[];

    im(I(ii),J(ii))=mean(tmp(:));


end
