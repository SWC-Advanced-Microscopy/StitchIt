function [section,param]=zPlane2section(zPlane,param)
% Convert a z-plane index to a section and optical index
%
% Purpose
% Identify which physical section and optical section a 
% z section comes from. 
%
% Inputs
% zPlane - a scalar defining the optical section we will search for. If a vector
%          we return an n-by-2 matrix with one plane per row
% param  - an optional parameter structure containing TV meta-data
%          i.e. these are data in a Mosaic*.txt file. If this is missing, 
%          we search for it and produce it here.
%
%
% Output
% section - a 2-element vector that is: [phsyical section, optical section]
% param - The parameter structure used for the calculations
%
%
% Rob Campbell - Basel 2014
%
% See also:
% handleSectionArg

if nargin<2
    param=readMetaData2Stitchit(getTiledAcquisitionParamFile); 
end

zPlane=zPlane(:);

section = [(floor((zPlane-1)/param.mosaic.numOpticalPlanes)+1)' ; ...
           (mod(zPlane-1,param.mosaic.numOpticalPlanes)+1)']';


