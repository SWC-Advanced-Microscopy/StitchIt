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
% The format of the meta-data is as follows. Below are shown only
% the fields that matter and really need to be there:
%
%  M.sample.ID - string defining the sample name
%  M.sample.objectiveName - string defining the objective name
%  M.sample.acqStartTime: e.g. '2017/03/07 16:09:04'
%  M.sample.activeChannels:  e.g. [1,3,4]
%  M.mosaic.sectionStartNum: 1
%  M.mosaic.numSections: 95
%  M.mosaic.sliceThickness: 100 (in microns)
%  M.mosaic.numOpticalPlanes: 3
%  M.mosaic.overlapProportion: 0.0700 (StitchIt calculates this for TissueVision data)
%  M.mosaic.scanmode: 'tile' (currently this is always "tile")
%  M.tile.nRows: 400 (num pixels per row in one tile)
%  M.tile.nColumns: 400 (num pixels per column in one tile)
%  M.voxelSize.X (in microns)
%  M.voxelSize.Y (in microns)
%  M.voxelSize.Z (in microns)
%  M.numTiles.X (number of tiles along X in the grid)
%  M.numTiles.Y (number of tiles along X in the grid)
%  M.TileStepSize.X - how far the stage moves in X between tile acquisitions in microns
%  M.TileStepSize.Y - how far the stage moves in Y between tile acquisitions in microns
%  M.System.ID - string defining the name of the acquisition system (used to read system-specific INI file)
%  M.System.type - string defining the type of system acquiring the data. e.g. TissueCyte, bakingtray, slidescanner, etc
%
%
%
% Developer Note:
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
