function [zPlane,param]=section2zPlane(section,param)
% Convert a section vector [physical_section,optical_section] to a z-plane index
%
% function [zPlane,param]=section2zPlane(section,param)
%
%
% Purpose
% Convert a section vector [physical_section,optical_section] to a z-plane index.
% A z-plane index is a scalar defining the optical layer in the sample as a whole.
%
%
% Inputs
% section - a vector defining the physical and optical section we will search for
% param  - an optional parameter structure containing TV meta-data
%          i.e. these are data in a Mosaic*.txt file. If this is missing, 
%          we search for it and produce it here.
%
%
% Output
% zPlane - a scalar defining a single, unique, physical section index in the whole tissue.
% param - The parameter structure used for the calculations
%
%
% Example
% section2zPlane([30,2])
%
%
%
% Rob Campbell - Basel 2014

if length(section)~=2
    error('section should be a vector with a length of 2')
end


if nargin<2
    param=readMetaData2Stitchit(getTiledAcquisitionParamFile); 
end

%Error check
if section(1)>param.mosaic.numSections
    error('Physical section %d does not exist. Maximum physical section is %d',...
        section(1), param.mosaic.numSections)
end

if section(2)>param.mosaic.numOpticalPlanes
    error('Optical section %d does not exist. Maximum optical section is %d',...
        section(2), param.mosaic.numOpticalPlanes)
end


% Determine the z-plane index, which is a scalar defining the optical layer in the sample as a whole.
zPlane=param.mosaic.numOpticalPlanes*(section(1)-1) + section(2);


