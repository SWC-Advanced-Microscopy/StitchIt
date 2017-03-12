function [data,nImages]=loadAveBinFile(fName,split)
% Load average image binary data for StitchIt
%
% function [data,nImages]=loadAveBinFile(fName,split)
%
%
% Purpose
% Load an average data bin file saved by writeAveBinFile. This, in turn, was
% called by preProcessTiles. We have made our own simple file format in order to 
% to incrementally add to average file. 
%
% The binary file is arranged as follows:
% [imagesInAverage,pixelRows,pixelColumns,DATA_FROM_EVEN_TILE_ROWS,DATA_FROM_EVEN_TILE_ROWS]
% all numbers are single precision. 
%
% 
% Inputs
% fName - a string defining the name of the average bin file to load
% split - an optional bool (1 by default). If 1, data is composed of two planes. 
%         The first being the even data and the second the odd data. If split is
%         zero we have just one plane, which is the mean of both odd and even. 
%
% Outputs
% data - the average data in the format described above (one or two planes).
%        returned data are means, divided by the number of averages that went into
%        making them. The first plane is even data and the second odd data. 
% nImages - the number of averages that went into creation of the returned data. 
%           NOTE that this number is *not* the number of tiles. preProcessTiles.m takes 
%           all the odd and even tiles from each optical plane does a trimmed mean on them. 
%           It is these means that are added and saved. The trimmed mean cleans up the 
%           data nicely in a way that a simple mean does not. 
%
%
% See writeAveBinFile and preProcessTiles for details. 
%
%
% Rob Campbell - Basel 2014


if ~exist(fName,'file')
    error('Can not find %s',fName)
end

if nargin<2
    split=1;
end

fid = fopen(fName,'r');

dataClass='uint16';
nImages = fread(fid,1,dataClass);
nRows = fread(fid,1,dataClass);
nCols = fread(fid,1,dataClass);

data = fread(fid,inf,dataClass); %read the rest 


data=reshape(data,[nRows,nCols,2]); %Reshape to make a matrix

if ~split
    data=mean(data,3);
end


fclose(fid);
