function avData = loadBruteForceMeanAveFile(coords,userConfig)

% function avData = loadBruteForceMeanAveFile(coords,userConfig)
%
% Determine the average filename (correct channel and optical plane/layer) from tile coordinates.
%
%

    layer=coords(2); %optical section
    chan=coords(5);

    %If we find a .bin file. Prompt the user to re-run collate average images to make the new-style files. 
    fname = fullfile(userConfig.subdir.rawDataDir, userConfig.subdir.averageDir, ...
        num2str(chan), sprintf('%02d.bin',layer));
    if exist(fname)
        fprintf('\n ===> ERROR: Found an old-style .bin file. Plase re-run collateAverageImages <===\n\n')
        avData=[];
    end

    fname = fullfile(userConfig.subdir.rawDataDir, userConfig.subdir.averageDir, ...
        num2str(chan), sprintf('%02d_bruteAverageTrimmean.mat',layer));

    if exist(fname,'file')
        load(fname) % Will produce the "avData" variable <------
    else
        avData=[];
        fprintf('%s Can not find average template file %s\n',mfilename,fname)
    end
