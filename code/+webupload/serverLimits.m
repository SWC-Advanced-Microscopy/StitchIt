function lim = serverLimits()
    % Limits and rules the client checks before sending, mirroring the server
    %
    % function lim = webupload.serverLimits()
    %
    % Purpose
    % maxZipBytes is max_zip_size from the shared contract (tests/web/upload_contract.json, copied
    % here as upload_core/tests/upload_contract.json; the server's config.php must match it). The
    % server config may set it lower, in which case the server's 413 still reports the problem.
    % idRegexp is the rule the server applies to site and microscope IDs. minUploadIntervalSec is
    % min_upload_interval_seconds from the same contract (lib.php falls back to 0 if unset):
    % the shortest gap between two
    % uploads from one site, microscope and source, which the server enforces with HTTP 429.
    % A site that raises it makes the client's copy too short.
    %
    % Outputs
    % lim - structure with fields maxZipBytes (zip size), idRegexp (pattern an ID must
    %       match) and minUploadIntervalSec.

    lim = struct('maxZipBytes', 200 * 1024^2, ...
                 'idRegexp', '^[A-Za-z][A-Za-z0-9_-]*$', ...
                 'minUploadIntervalSec', 5);
end % serverLimits
