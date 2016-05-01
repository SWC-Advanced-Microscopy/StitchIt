function E=findTileEdges(mask)

disp('WARNING: need to find edge pixels on both sides of the boundary!')

mask=int8(mask);
E = zeros(size(mask),class(mask));

tmp = abs(diff(mask,1,1));
E(1:end-1,:) = E(1:end-1,:)+tmp;

tmp = abs(diff(mask,1,2));
E(:,2:end) = E(:,2:end)+tmp;


E(E~=0) = 1;

E=uint8(E);