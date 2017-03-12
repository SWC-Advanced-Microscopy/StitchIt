function returnedClass = returnSystemSpecificClass
% Determine the acquisition system used for this experiment and return the class that handles this
%
%    function returnedClass = returnSystemSpecificClass
%
%
% Purpose
% StitchIt can in principle handle a variety of different data acquisition systems.
% The TissueCyte is the best supported, but the idea is that users can extend StitchIt
% simply by writing custom functions for indexing and loading tiles. 
%  
% This function returns the identity of the system that gathered the data by looking
% for key file names in the experiment directory. These are assigned as follows.
%
% A "Mosaic" file indicates a TissueCyte dataset
% A "Tray" file indicates a BakingTray dataset
%
%
% Inputs
% functionName - none
% 
% Outputs
% returnedClass - a class that provides all the system-specifc methods needed to assemble a dataset
%
%
%
% Example
% From within a function you might do:
% returnedClass = returnSystemSpecificClass
% returnedClass.someFunction
% 
%
% Rob Campbell - Basel 2015
%
% NOTE:
% If you want to modify StitchIt to handle data from a different system type, you should edit 
% this file and add your custom code then build a class that inherits micSys. See the TissueCyte
% class as an example.



switch determineStitchItSystemType;
case 'TissueCyte'
    returnedClass=tissuecyte;
case 'BakingTray'
    returnedClass=bakingtray;
otherwise
    error('Can not find acquisition system log file in %s\n',pwd)
end
