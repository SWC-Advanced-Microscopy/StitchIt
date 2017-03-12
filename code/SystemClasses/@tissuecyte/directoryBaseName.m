function baseName=directoryBaseName(~,parameterFile)
% For user documentation run "help directoryBaseName" at the command line

if nargin<2
    parameterFile=getTiledAcquisitionParamFile;
end

if isempty(parameterFile)
    error('Can not find a Mosaic file in the current directory\n')
end

tok=regexp(parameterFile,'Mosaic_(.*)\.txt','tokens');

if isempty(tok)
    error('Can not generate base name')
end

baseName=[tok{1}{1},'-'];
