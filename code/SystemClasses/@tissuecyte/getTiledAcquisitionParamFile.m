function paramFile = getTiledAcquisitionParamFile(obj,supressWarning)

if nargin<2
    supressWarning=0;
end

D=dir('Mosaic*.txt');
if isempty(D)
    if ~supressWarning
        fprintf('%s: Failed to find a Mosaic file in the current directory\n',mfilename)
    end
    paramFile=[];
    return
end

if length(D)>1
    if ~supressWarning
        fprintf('%s: Found multiple Mosaic files. Please specify a single file\n', mfilename)
    end
    paramFile=[];
    return
end

paramFile=D.name;
