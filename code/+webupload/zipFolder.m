function zipPath = zipFolder(dirPath)
    % Zip the recognised preview files in a folder into a temporary .zip
    %
    % function zipPath = webupload.zipFolder(dirPath)
    %
    % Purpose
    % Only files the server keeps (see webupload.selectUploadable) are included, and the
    % archive is flat: subfolders are ignored and entries carry no path. Filtering here keeps
    % the upload small; the server filters again, so this is an optimisation, not a security
    % boundary.
    %
    % Errors if the folder does not exist, holds no uploadable files, or the zip would exceed
    % the server's size limit. The caller owns the returned file and should delete it after posting
    % (webupload.zipAndPost does this).
    %
    % Inputs
    % dirPath - path to the folder to zip.
    %
    % Outputs
    % zipPath - path to the temporary zip file.


    if ~isfolder(dirPath)
        error('webupload:noSuchFolder', 'Folder not found: %s', dirPath);
    end

    names = webupload.selectUploadable(dirPath);
    if isempty(names)
        error('webupload:noFiles', ...
            'No files with an uploadable name (%s) in %s', ...
            strjoin(webupload.allowedNames(), ' '), dirPath);
    end


    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    % Names relative to dirPath (the rootfolder argument) make the archive flat
    zipPath = [tempname, '.zip'];
    try
        zip(zipPath, names, dirPath);
    catch err
        if isfile(zipPath) % do not leave a partial archive in tmp
            delete(zipPath);
        end
        rethrow(err);
    end

    if ~isfile(zipPath)
        error('webupload:zipFailed', 'zip() did not create %s', zipPath);
    end

    lim = webupload.serverLimits();
    info = dir(zipPath);
    if info.bytes > lim.maxZipBytes
        delete(zipPath);
        error('webupload:zipTooLarge', ...
            'Zip is %.1f MB; the server accepts at most %.0f MB.', ...
            info.bytes / 1024^2, lim.maxZipBytes / 1024^2);
    end
end % zipFolder
