function writeAveBinFile(fName,evenData,oddData,imagesInAve)
% Write average image binary file
%
% function writeAveBinFile(fName,evenData,oddData,imagesInAve)
%
% TODO: update help now that we've changed how we do this (no singles)
% Purpose
% We want to incrementally add to average file. e.g. say we process half the 
% data now and the other half tomorrow. We want to be able to improve the 
% quality of the average file. To do this, we create this simple file format.
%
% The binary file is arranged as follows:
% [imagesInAverage,pixelRows,pixelColumns,DATA_FROM_EVEN_TILE_ROWS,DATA_FROM_EVEN_TILE_ROWS]
% all numbers are single precision. 
%
% The idea is that the data are a *sum* and not an average. So that's why we want
% singles, since we have the headroom for the very large numbers which we'll need. 
% This function saves the data. The corresponding readAveBinFile loads the data. 
% 
% The reason we do things this way is because we will be able to identify large 
% inconsistencies between the number of images contributing to the data 
% and the data contents. This allows us to issue a warning on file reading and
% prompt the user to re-create the average. We can also more flexibly load data
% (pool across odd and even or not)
%
%
% NOTE that the number of images that went into the average is *not* the number of
% tiles. preProcessTiles.m takes all the odd and even tiles from each optical plane
% does a trimmed mean on them. It is these means that are added and saved. The trimmed
% mean cleans up the data nicely in a way that a simple mean does not. 
%
% Rob Campbell - Basel 2014



if any(size(evenData)-size(oddData))
    error('evenData and oddData must be the same size\n')
end


evenData = uint16(evenData);
oddData = uint16(oddData);


nRows = size(evenData,1);
nCols = size(evenData,2);

fid = fopen(fName,'w+');

fwrite(fid,[imagesInAve,nRows,nCols],'uint16'); %The "header" information
fwrite(fid,[evenData(:);oddData(:)],'uint16'); %The data

fclose(fid);