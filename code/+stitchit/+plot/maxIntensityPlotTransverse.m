function [M1,mu1,med1] = maxIntensityPlotTransverse(stitchedDir)
% Calculate maximum intensity projection (transverse) using a set of stitched images
%
% function [M1,mu1,med1] = maxIntensityPlot(stitchedDir,sectionRange)
%
% Purpose
% Calculate the maximum intensity projection of a stitched data set. 
% Images are loaded in parallel and incrementally, so arbitrarily large
% stacks can be processed. 
%
% Inputs
% stitchedDir - string defining the locations of the stitched images. 
% sectionRange - [firstSection,lastSection] optional. By default all sections are used.
%

% Rob Campbell - Basel 2015

if strcmp(stitchedDir(end),filesep)
    stitchedDir(end)=[];
end

if ~exist(stitchedDir,'dir')
    error('Directory %s not found',stitchedDir)
end


tifs = dir([stitchedDir,filesep,'*.tif']);


if isempty(tifs)
    error('No tifs found in %s', stitchedDir)
end




tmp=stitchit.tools.openTiff([stitchedDir,filesep,tifs(1).name]);

M1=max(tmp,[],1);
mu1=mean(tmp,1);
med1=median(tmp,1);


M1=repmat(M1,[length(tifs)],1);
mu1=repmat(mu1,[length(tifs)],1);
med1=repmat(med1,[length(tifs)],1);


parfor ii=2:length(tifs)

    IM=stitchit.tools.openTiff([stitchedDir,filesep,tifs(ii).name]);

    M1(ii,:)=max(IM,[],1);
    mu1(ii,:)=mean(IM,1);
    med1(ii,:)=median(IM,1);

end

