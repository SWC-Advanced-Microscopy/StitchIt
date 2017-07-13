function data=loadAveBinFile(fName)
% Load average image binary data for StitchIt
%
% function data=loadAveBinFile(fName)
%
%
% Purpose
% Load an average data bin file saved by writeAveBinFile. This, in turn, was
% called by preProcessTiles. We have made our own simple file format in order to 
% to incrementally add to average file. This is a legacy function.
%
% The binary file is arranged as follows:
% [imagesInAverage,pixelRows,pixelColumns,DATA_FROM_EVEN_TILE_ROWS,DATA_FROM_EVEN_TILE_ROWS]
% all numbers are single precision. 
%
% NOTE: if called on a .mat file, then this function just loads it and returns it. 
%
% Inputs
% fName - a string defining the name of the average bin file to load. Can also
%        be a .mat file, in which case it just loads it and returns it.
%
%
% Outputs
% data - A structure containing the following fields:
%    evenRows - an average image formed from the even rows
%    oddRows - an average image formed from the odd rows
%    pooledRows - a pooled average image
%    evenN - an estimate (don't ask...) of the number of images going into the evenRows image
%    oddN - the number of images going into the odd rows image
%    poolN - the sum of evenN and oddN
%    correctionType -  'bruteAverageTrimmean' string defining how the images are calculated
%    channel - the channel this average is from (left blank here)
%    layer - the optical plane (depth) in the sample this average is from 
%    details - an empty structure which could contain optional data
%
%
% See writeAveBinFile and preProcessTiles for details. 
%
%
% Rob Campbell - Basel, 2014
%                Basel, 2017 - updated to return a structure


if ~exist(fName,'file')
    error('Can not find %s',fName)
end

[~,~,ext] = fileparts(fName);
if strmatch(ext,'.mat')
    load(fName);
    data=avData; % Will crash if this wasn't an average image structure
    return
end

fid = fopen(fName,'r');

dataClass='uint16';
nImages = fread(fid,1,dataClass);
nRows = fread(fid,1,dataClass);
nCols = fread(fid,1,dataClass);

binData = fread(fid,inf,dataClass); %read the rest 

% Reshape to make a matrix:
% The first plane is even data and the second odd data. 
aveIm=reshape(binData,[nRows,nCols,2]); 

fclose(fid);

% Figure out the depth from the file name
tok=regexp(fName,'.*?(\d+)\.bin','tokens');
depth=str2num(tok{1}{1});


% Make the output structure
data.evenRows = aveIm(:,:,1);
data.oddRows = aveIm(:,:,2);
data.pooledRows = mean(aveIm,3);
data.evenN=nImages;
data.oddN=nImages;
data.poolN=nImages*2;
data.correctionType='bruteAverageTrimmean';
data.channel = [];
data.layer = depth;
data.details=struct;
