function [ch1,ch2,chmu1,chmu2] = maxIntensityPlotTransverse(stitchedDir)
% Calculate maximum intensity projection (transverse) using a set of stitched images
%
% function varargout = maxIntensityPlot(stitchedDir,sectionRange)
%
% Purpose
% Calculate the maximum intensity projection of a stitched data set. 
% Images are loaded in parallel and incrementally, so arbitrarily large
% stacks can be processed. "clean" because it uses channel 1 and 2 to make a neater image.
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





[ch1,chmu1]=maxIntensityPlotTransverse(['stitchedImages_010',filesep,'1']);  
[ch2,chmu2]=maxIntensityPlotTransverse(['stitchedImages_010',filesep,'2']);  
