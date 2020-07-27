function out = finished
    % Return true if the finished file is present. false otherwise.
    %
    % Inputs
    % none
    %
    % Outputs
    % out - true if a "FINISHED" file is present. false otherwise
    %

    config=readStitchItINI;

    if exist('FINISHED','file') || ...
        exist('FINISHED.txt','file') || ...
        exist(fullfile(config.subdir.rawDataDir,'FINISHED'))  || ...
        exist(fullfile(config.subdir.rawDataDir,'FINISHED.txt'),'file')

        out = true;
    else
        out = false;
    end
