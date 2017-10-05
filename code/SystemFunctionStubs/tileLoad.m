function [im,index]=tileLoad(coords,varargin)
% Load raw tile data as a stack for processing by StitchIt
%
% function [im,index]=tileLoad(coords,'Param1', Val1, 'Param2', Val2, ...)
%
% PURPOSE
% Load either a single tile from a defined section, optical section, and channel,
% or load a whole tile (all TIFFs) from a defined section, optical section, 
% and channel. 
%
%
% INPUTS (required)
% coords - a vector of length 5 4 with the fields:
%     [physical section, optical section, yID, xID,channel]
%
% All indecies start at 1. If yID or xID is zero we slice. 
% e.g. To load all tiles from section 10, optical section 3, channel 1 we do:
%    zID 10 we do: [10,3,0,0,1]. Note that if you have only one optical section
%    per physical section then you still need to do: [10,1,0,0,1]
%
%
% INPUTS (optional, for advanced users)
% doIlluminationCorrection - By default do what's defined in the INI file. Otherwise 
%                            this may be true (apply correction) or false (do not apply correction).
% doCrop - By default crop all four edges by the value defined in the INI file.
%          If cropBy is false, no cropping is performed. If true it is performed.
% doPhaseCorrection - Apply pre-loaded phase correction. If false don't apply. If true apply.
%                     By default do what is specified in the INI file.
% verbsose - false by default. If true, debug information is printed to screen.  
%
% doSubtractOffset - Apply offset correction to raw images. If false don't apply. If true apply 
%                    (if possible to apply). Otherwise do what is in INI file.
%                    If the offset correction was used to calculate the average tiles then it is 
%                    integrated into these averages. So you might get odd results if you choose
%                    disable the offset correction and use average tiles that include it. Under
%                    these circumstances you might want to re-generate the average images. 
%                    Equally, if the offset was not calculated then it's not incorporated into the 
%                    average and the offset value will be forced to be zero. So the doSubtractOffset
%                    value will have no effect in this case. 
%
%
%
% OUTPUTS
% im - The image or image stack at 16 bit unsigned integers.
% index - The index data of each tile (see readTileIndex) allowing the locations
%         of the tiles in the mosaic to be determined. 
%
%
% EXAMPLES
% >> T=tileLoad([1,1,0,0,3]);
% >> T=tileLoad([1,1,0,0,3],'doCrop',false);
%
%
%
% Rob Campbell - Basel 2014
%               updated to handle param/value pairs - Basel 2017
%
%
% See also readTileIndex, generateTileIndex


if length(coords)~=5
    % coords - a vector of length 5 with the fields:
    %     [physical section, optical section, yID, xID,channel]
    error('Coords should have a length of 5. Instead it has a length of %d', length(coords))
end


% Parse optional inputs
IN = inputParser;
IN.CaseSensitive = false;

valChk = @(x) islogical(x) || x==0 || x==1 || isempty(x);
IN.addParamValue('doIlluminationCorrection', [], valChk);
IN.addParamValue('doCrop', [], @(x) islogical(x) || x==0 || x==1 || isempty(x));
IN.addParamValue('doCombCorrection', [], @(x) islogical(x) || x==0 || x==1 || isempty(x));
IN.addParamValue('doSubtractOffset', [], @(x) islogical(x) || x==0 || x==1 || isempty(x));
IN.addParamValue('verbose', false, @(x) islogical(x) || x==0 || x==1 );

IN.parse(varargin{:});

doIlluminationCorrection = IN.Results.doIlluminationCorrection;
doCrop = IN.Results.doCrop;
doCombCorrection = IN.Results.doCombCorrection;
doSubtractOffset = IN.Results.doSubtractOffset;
verbose = IN.Results.verbose;


%NOTE:
% This function instantiates an object specific to the data acquisition system being used
% then calls a method with the same name as this function. For implementation details see
% the SystemClasses directory. 
OBJECT=returnSystemSpecificClass;
[im,index] = OBJECT.(mfilename)(coords,doIlluminationCorrection,doCrop,doCombCorrection,doSubtractOffset,verbose);
