function mosaicFile = getTiledAcquisitionParamFile(varargin)
% Look for a the acquisition system's parameter  file in the current directory and return its name
%
% function mosaicFile = getTiledAcquisitionParamFile(supressWarning)
%
% Purpose
% Return the name of the parameter file created by the acquisition system. 
% e.g. for the TissueCyte this is called a "Mosaic" file.
%
%
% Inputs
% supressWarning - optionally supress warning about missing mosaic file
%
%
% Rob Campbell
%
% Also see: directoryBaseName, getTiledAcquisitionParamFile


%NOTE:
% This function instantiates an object specific to the data acquisition system being used
% then calls a method with the same name as this function. For implementation details see
% the SystemClasses directory. 
OBJECT=returnSystemSpecificClass;
mosaicFile = OBJECT.(mfilename)(varargin{:});
