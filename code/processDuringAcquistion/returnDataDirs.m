function dataDirs=returnDataDirs(rawDataDir)
    % Return directories that are likely section directories based on the name
    %
    %

    potentialDirs=dir([rawDataDir,filesep,'*-0*']); %TODO: should enforce that this ends with a number?
    dataDirs=potentialDirs([potentialDirs.isdir]==true);
