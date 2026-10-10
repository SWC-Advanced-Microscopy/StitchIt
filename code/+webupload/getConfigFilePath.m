function cfgPath = getConfigFilePath(verbose)
    % Return file path to the config (token) file
    %
    % function cfgPath = webupload.getConfigFilePath(verbose)
    %
    % Inputs (optional)
    % verbose - false by default. If true, reports the path to the file if found
    %

    if nargin<1
        verbose = false;
    end

    configFileFname = 'brainsaw_webpreview.json';

    numConfigFilesFound = numel(which(configFileFname,'-all'));
    if numConfigFilesFound>1
        fprintf('WARNING: Found %d %s files choosing the first one\n', ...
            numConfigFilesFound, configFileFname);
    end

    cfgPath = which(configFileFname);


    if verbose
        if ~isempty(cfgPath)
            fprintf('webupload config file found at %s\n', cfgPath)
        else
            fprintf('No webupload config file found\n')
        end
    end

