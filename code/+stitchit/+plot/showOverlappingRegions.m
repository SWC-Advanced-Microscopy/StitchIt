function showOverlappingRegions(coords) 
%Given a single tile, load adjacent tiles and plot overlapping regions next to each other
%
% function showOverlappingRegions(coords) 
%
% INPUTS
% coords = [physical section, optical section, YID, XID, channel]
%
%
% Rob Campbell - Basel, 2014

illum=0;
crop=15;

clf



S=[0.55,0.55];

%CENTRAL TILE
axes('position',[0.25,0.25,S]);
centralTile = tileLoad(coords,illum,crop);
showTile(centralTile)


%Top
axes('position',[0.25,0.81,S]);
tCoords=coords;
tCoords(3)=coords(3)-1;
top = tileLoad(tCoords,illum,crop);
showTile(top)



%bottom
axes('position',[0.25,-0.31,S]);
tCoords=coords;
tCoords(3)=coords(3)+1;
bottom = tileLoad(tCoords,illum,crop);
showTile(bottom)


%left
axes('position',[-0.16, 0.25,S]);
tCoords=coords;
tCoords(4)=coords(4)-1;
left = tileLoad(tCoords,illum,crop);
showTile(left)


axes('position',[0.66,0.25,S]);
tCoords=coords;
tCoords(4)=coords(4)+1;
right = tileLoad(tCoords,illum,crop);
showTile(right)



colormap gray



function showTile(tile)
    imagesc(tile)
    axis equal tight off
    set(gca,'CLim',[0,3000])

    %Add some markers to indicate overlapping areas
    imSize=size(tile,1);

    hold on


    ov=0.045*imSize; %approx overlap at fast axis (give or take)
    props={'-','color',[1,0.5,0.5]};
    plot([ov,ov],[0,imSize],props{:})
    plot(imSize-[ov,ov],[0,imSize],props{:})


    ov=0.049*imSize; %approx overlap at slow axis
    plot([0,imSize],[ov,ov],props{:})
    plot([0,imSize],imSize-[ov,ov],props{:})