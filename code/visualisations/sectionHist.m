function sectionHist(im,thresh)
% Make an appealing histogram of a TV optical section
%
%
% sectionHist(im,thresh)
%
% If "thresh" is specified (a scalar between 0 and 2^16) then we draw a dashed red 
% line at this point.
%
%
% Rob Campbell



%Ditch the really low values to speed things up, since we're going to convert to single
bottomThresh=100;
im(im<bottomThresh)=[];
im=single(im(:));


[n,x]=hist(im,750);



bg=[1,1,1]*0.1;


clf
B=bar(x,n,1);
H=findobj(gca,'Type','Patch');

ylim([0,  max(n)+1])


set(H,'FaceColor',[1,1,1]*0.2,'EdgeColor','w')
set(gcf,'color',bg)
set(gca,'color',bg,'XScale','log','YlimMode','manual')
xlim([bottomThresh,(2^16)/2])

set(gca,'XColor','w','YColor','w')


%optionally draw bar
if nargin>1
    if thresh<1 or thresh >2^16
        fprintf('Thresh out of range\n')
    end
    
    hold on 
    plot([thresh,thresh],ylim,'--','Color',[1,0.5,0.5],'LineWidth',2)
    hold off
end
