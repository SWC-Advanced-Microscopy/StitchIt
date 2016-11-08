function [out,sucessfulRead,mosOut]=readMetaData2Stitchit(varargin)
% Read acquisition meta data into a MATLAB structure
%
% function [out,sucessfulRead]=readMetaData2Stitchit(fname,verbose)
%
% Purpose
% Read meta-data from a tiled acquisition parameter file and returns 
% mosaic meta data as a structure that StitchIt can handle. 
%
%
% Inputs
% fname - relative or absolute path to mosaic meta-data file.
% verbose - [optional, 0 by default] 
%
% 
% Outputs
% out - a structure containing the metadata
% sucessfulRead - 0 if the read failed for some reason. 1 otherwise.
% rawOut - the output of raw read (TODO: should get rid of this)
%
%
% Note:
% This function should avoid calling readStitchItINI in order to avoid
% recursion situations. 
% 
%
%
% Rob Campbell - Basel 2016

%NOTE:
% This function instantiates an object specific to the data acquisition system being used
% then calls a method with the same name as this function. For implementation details see
% the SystemClasses directory. 
OBJECT=returnSystemSpecificClass;
[out,sucessfulRead,mosOut] = OBJECT.(mfilename)(varargin{:});
