function result = zipAndPost(folder, cfg, micID, source, varargin)
    % Zip a folder's preview files, upload them and clean up; never throws
    %
    % function result = webupload.zipAndPost(folder, cfg, micID, source, ...
    %                                          'ConnectTimeout', 5, 'ResponseTimeout', 10, ...
    %                                          'DataTimeout', 10)
    %
    % Purpose
    % The entry point for instrument and analysis code. Any failure (missing folder, no files, too large,
    % network, bad cfg) is returned as result.ok = false with a message, with the token
    % scrubbed by postZip, so the caller is never interrupted. The temp zip is always deleted.
    % Blocks for up to the postZip timeouts. The folder must hold recipe.yml and status.json
    % or the server refuses the upload. micID, source and the optional timeouts are passed
    % to postZip, which documents them and validates them.
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
    %
    % Outputs
    % result - structure with fields ok, httpStatus and message.

    result = struct('ok', false, 'httpStatus', NaN, 'message', '');
    try
        zipPath = webupload.zipFolder(folder);
        cleaner = onCleanup(@() deleteQuietly(zipPath)); %#ok<NASGU> runs on scope exit
        result = webupload.postZip(zipPath, cfg, micID, source, varargin{:});
    catch err
        result.message = err.message;
    end
end % zipAndPost


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
