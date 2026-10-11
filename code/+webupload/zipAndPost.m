function result = zipAndPost(folder, cfg, micID, source, varargin)
    % Zip a folder's preview files, upload them and clean up; never throws
    %
    % function result = webupload.zipAndPost(folder, cfg, micID, source, ...
    %                                          'ConnectTimeout', 5, 'ResponseTimeout', 10, ...
    %                                          'DataTimeout', 10, 'Background', false)
    %
    % Purpose
    % The entry point for instrument and analysis code. Any failure (missing folder, no files, too large,
    % network, bad cfg) is returned as result.ok = false with a message, with the token
    % scrubbed by postZip, so the caller is never interrupted. The temp zip is deleted, except
    % after a successful 'Background' launch (below). Blocks for up to the postZip timeouts,
    % unless 'Background' is true. The folder must hold recipe.yml and status.json
    % or the server refuses the upload. micID, source and the optional timeouts are passed
    % to postZip, which documents them and validates them.
    %
    % With 'Background', true postZip starts a detached curl and returns at once. That curl is
    % still reading the zip after this function returns, so the zip is not deleted here: the
    % launched command deletes it (and the curl config) when curl exits. If the launch fails the
    % zip is deleted here as usual.
    %
    % Inputs
    % folder - path to the folder holding the preview files.
    % cfg - webupload.webConfig object holding the upload configuration. Anything else is
    %       reported as a failure by postZip.
    % micID - microscope ID as returned by webupload.readRecipe.
    % source - 'acq' or 'analysis'.
    %
    % Inputs (optional param/val pairs)
    % 'ConnectTimeout', 'ResponseTimeout', 'DataTimeout' - per-call timeouts in seconds, see
    %                     postZip.
    % 'Background' - Logical scalar, default false. See above and postZip.
    %
    % Outputs
    % result - structure with fields ok, httpStatus, message and background (true only after a
    %          successful background launch).

    result = struct('ok', false, 'httpStatus', NaN, 'message', '', 'background', false);
    try
        zipPath = webupload.zipFolder(folder);
        % A handle, so the cleanup (which also runs on Ctrl-C) can see whether the launched
        % command has taken over the zip
        handedOver = containers.Map('KeyType', 'char', 'ValueType', 'logical');
        handedOver('yes') = false;
        cleaner = onCleanup(@() deleteUnlessHandedOver(zipPath, handedOver)); %#ok<NASGU> runs on scope exit
        result = webupload.postZip(zipPath, cfg, micID, source, varargin{:});
        handedOver('yes') = isfield(result, 'background') && isequal(result.background, true);
    catch err
        result.message = err.message;
    end
end % zipAndPost


function deleteUnlessHandedOver(path, handedOver)
    % Delete the zip unless a background curl now owns it
    %
    % function webupload.zipAndPost>deleteUnlessHandedOver(path, handedOver)
    %
    % Inputs
    % path       - Path of the temp zip.
    % handedOver - containers.Map whose 'yes' entry is true once the launched command is
    %              responsible for deleting the zip.

    if ~handedOver('yes')
        deleteQuietly(path);
    end
end % deleteUnlessHandedOver


function deleteQuietly(path)
    % Delete a file if it exists
    %
    % function webupload.zipAndPost>deleteQuietly(path)
    %
    % Purpose
    % Used to remove the temporary zip. Does nothing if the file is already gone.
    %
    % Inputs
    % path - Path to the file to delete.

    if isfile(path)
        delete(path);
    end
end % deleteQuietly
