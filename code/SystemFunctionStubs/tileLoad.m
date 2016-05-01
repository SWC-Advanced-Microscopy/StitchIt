function [im,index]=tileLoad(varargin)
% Load raw tile data for StitchIt
%
% function [im,index]=tileLoad(coords,doIlluminationCorrection,doCrop)
%
% PURPOSE
% Load either a single tile from a defined section, optical section, and channel,
% or load a whole tile (all TIFFs) from a defined section, optical section, 
% and channel. 
%
% INPUTS
% coords - a vector of length 5 4 with the fields:
%     [physical section, optical section, yID, xID,channel]
%
% All indecies start at 1. If yID or xID is zero we slice. 
% e.g. To load all tiles from section 10, optical section 3, channel 1 we do:
%    zID 10 we do: [10,3,0,0,1]. Note that if you have only one optical section
%    per physical section then you still need to do: [10,1,0,0,1]
%
% doIlluminationCorrection - empty (do what's in INI file) by default. Otherwise 
%                            1 and 0 do and do not correct.
%        
% doCrop - crop all four edges. if zero don't crop. if 1 crop by a default value 
%        defined in the INI file. Empty by default and so follows what is in the 
%        INI file. Cropping is typically around 2.16% of the original 
%        image size. e.g. for a 1664x1664 image it's 36 pixels. 
%
% doPhaseCorrection - apply pre-loaded phase correction. if zero don't apply. 
%                     empty by default, in which case we do what is specified 
%                     in the INI file. 
%
%
% Outputs
% im - The image or image stack at 16 bit unsigned integers.
% index - The index data of each tile (see readTileIndex) allowing the locations
%         of the tiles in the mosaic to be determined. 
%
%
% Rob Campbell - Basel 2014
%
% See also readTileIndex, generateTileIndex


%NOTE:
% This function instantiates an object specific to the data acquisition system being used
% then calls a method with the same name as this function. For implementation details see
% the SystemClasses directory. 
OBJECT=returnSystemSpecificClass;
[im,index] = OBJECT.(mfilename)(varargin{:});
