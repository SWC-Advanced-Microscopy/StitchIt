function baseName=directoryBaseName(~,parameterFile)
% For user documentation run "help directoryBaseName" at the command line

if nargin<2
    parameterFile=getTiledAcquisitionParamFile;
end


if isempty(parameterFile)
    error('Can not find a BakingTray recipe file in the current directory\n')
end

params = yaml.ReadYaml(parameterFile);

baseName = [params.sample.ID,'-'];
