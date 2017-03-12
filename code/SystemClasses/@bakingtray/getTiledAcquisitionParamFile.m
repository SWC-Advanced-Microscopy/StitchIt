function paramFile = getTiledAcquisitionParamFile(obj,supressWarning)


if nargin<2
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
    if ~supressWarning
        fprintf('%s: Found multiple recipe files. Please specify a single file\n', mfilename)
    end
    paramFile=[];
    return
end

paramFile=D.name;
