function paramFile = getTiledAcquisitionParamFile(supressWarning)
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



if nargin<1
    supressWarning=0;
end

D=dir('*recipe*.yml');
if isempty(D)
    if ~supressWarning
        fprintf('%s: Failed to find a recipe file in the current directory\n',mfilename)
    end
    paramFile=[];
    return
end

if length(D)>1
    D = D(end); %Load the most recent (file names include date and time)
end

paramFile=D.name;
