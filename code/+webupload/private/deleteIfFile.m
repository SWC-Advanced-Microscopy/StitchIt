function deleteIfFile(path)
    % Delete a file if it exists, bypassing the recycle bin
    %
    % function deleteIfFile(path)
    %
    % Purpose
    % Private to +webupload. Used for the temporary zip and the curl config, which holds the
    % token, so neither may linger in a recycle bin. The previous recycle setting is
    % restored afterwards.
    %
    % Inputs
    % path - path of the file; nothing happens if it does not exist.

    if isfile(path)
        previous = recycle('off');
        restore = onCleanup(@() recycle(previous)); %#ok<NASGU> runs on scope exit
        delete(path);
    end
end % deleteIfFile
