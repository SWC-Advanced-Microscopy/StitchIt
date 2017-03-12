function availableChans=channelsAvailableForStitching(varargin)
% Determine the number of available channels in the raw data that can be stitched
%
% function availableChans=channelsAvailableForStitching
%
% PURPOSE
% The meta-data file that stores the acquisition may not accurately reflect which 
% channels are actually present and available for stitching. e.g. Because the
% Orchestrator-Vivace software of TissueVision does not provide the option to 
% select channels and sometimes one is deleted after acquisition if it's not 
% needed. This function therefore looks in the raw data directory and figures
% out which channels are available. It returns this information as a vector of
% channel IDs. It achieves this by looking in the first section directory. So
% the assumption is that all section directories have the same number of channels. 
% There is no check as to whether this is really the case. 
%
% INPUTS
% None
%
% OUTPUTS
% availableChans - a vector of channel IDs available for stitching. 
%
%
% Rob Campbell - Basel 2017
%
% See also - stitchAllChannels

%NOTE:
% This function instantiates an object specific to the data acquisition system being used
% then calls a method with the same name as this function. For implementation details see
% the SystemClasses directory. 
OBJECT=returnSystemSpecificClass;
availableChans = OBJECT.(mfilename)(varargin{:});
