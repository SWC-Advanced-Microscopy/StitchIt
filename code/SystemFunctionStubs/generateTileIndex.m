function [nCompleted,indexPresent] = generateTileIndex(varargin)
% Index all raw data tiles in an experiment, link original file names to position in tile array 
%
%
% A tile is defined as a single 2-D image. Each tile is located in a unique position in the
% 3-D sample. StitchIt uses an index file to associate each tile coordinate with a file. 
% The index file is called "tileIndex" and is present in each raw data directory. 
% The file is binary. It's composed of 32 bit unsigned ints. The first int defines the
% size of one record row. This function doesn't load the TIFFs. It simply indexes 
% based on file names. 
%
% function [nCompleted,indexPresent] = generateTileIndex(sectionDir,forceOverwrite,verbose)
% 
%
% INPUTS
% sectionDir - [empty or string]. If a string, it should be the name of a section directory
%               within the raw data dirctory. If so we generate the index for this directory only. 
%               Otherwise (if empty) the function loops through all section directories in the
%               raw data directory.
% forceOverwrite - zero by default. If 1 the function over-write existing the existing
%                  tileIndex file
% verbose - few messages if 0. 1 by default, for more messages.
%
%
% OUTPUTS
% nCompleted - Optionally return the number of directories containing an index file 
% indexPresent - vector indicating which sections have a tile index file and which do not.
%
%
% EXAMPLES
% 1) Loop through all directories and add tileIndex files only where they're missing:
% generateTileIndex
% or
% generateTileIndex([],0)
%
% 2) Regenerate all tile index files in all directories
% generateTileIndex([],1)
%
% 3) Regenerate tile index file for section 33 only (rawData directory appended automatically)
% generateTileIndex('K102-0001',1) 
%
% 4) how many directories contain an index file
% n = generateTileIndex;
%
%
%
% Rob Campbell - Basel 2014
%
%
% See also: readTileIndex


%NOTE:
% This function instantiates an object specific to the data acquisition system being used
% then calls a method with the same name as this function. For implementation details see
% the SystemClasses directory. 
OBJECT=returnSystemSpecificClass;
[nCompleted,indexPresent] = OBJECT.(mfilename)(varargin{:});
