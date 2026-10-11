function result = postZip(zipPath, cfg, micID, source, varargin)
    % Upload a zip to the brainsaw server; never throws
    %
    % function result = webupload.postZip(zipPath, cfg, micID, source, ...
    %                                      'ConnectTimeout', 5, 'ResponseTimeout', 10, ...
    %                                      'DataTimeout', 10, 'Background', false)
    %
    % Purpose
    % Uploads the zip with a bearer token. cfg is a webupload.webConfig object, which has
    % already checked the url (https only), siteID and token when it was created. Its
    % connectTimeout, responseTimeout and dataTimeout properties (seconds; defaults 15, 60,
    % 60) set the timeouts. The token is sent with cfg.authHeader, so it is never read here.
    %
    % The form fields sent are site_id (from cfg), microscope_id (micID), source and data
    % (the zip). The zip must contain recipe.yml and status.json or the server refuses it
    % (see webupload.readRecipe and webupload.writeStatus). micID and source are checked
    % here, before anything is sent: source must be 'acq' or 'analysis' and micID must
    % match the server's ID rule (webupload.serverLimits().idRegexp). If not, ok is false,
    % the message says whether the ID was missing or invalid and shows the value, and no
    % request is made. Both may be char or string.
    %
    % The multipart body is assembled in memory (buildMultipart) so the request has a
    % Content-Length. The brainsaw server's PHP runs under FastCGI on IONOS and silently drops
    % every form field, including site_id, from a request sent without one (chunked transfer
    % encoding), which shows up as "unknown site_id". The whole zip is read into memory; real
    % preview zips are a few MB and the server limit is 200 MB.
    %
    % Redirects are never followed: the request carries a bearer token, and a redirect could
    % send it to an http:// or other host. A 3xx answer returns ok = false.
    %
    % By default the call is synchronous: it blocks until the server answers or a timeout fires, so a
    % dead or stalled server delays the caller by about the timeouts. Whether ResponseTimeout
    % and DataTimeout cover the transfer of the upload itself is unverified; a warning
    % (webupload:postZip:noTimeout) is issued if this MATLAB release lacks either property.
    %
    % With 'Background', true the call does not wait. After the checks above it writes a curl
    % config file in tempdir (the url, the Authorization header, the form fields and the
    % timeouts; see webupload.curlConfigText) and starts curl detached, using the shell
    % command from webupload.backgroundCommand. The token is in that file, never on a command
    % line, so it does not show in ps or Task Manager; on unix the file is created readable
    % only by the user. The same command deletes the config file and the zip once curl exits,
    % whether or not the upload worked, so the caller must not delete the zip when
    % result.background is true (zipAndPost does this). The outcome of the upload is never
    % seen: result.ok = true means only that the launch command returned success, which is
    % best effort: it shows the shell started, not that curl did. Failure to start (config
    % file not writable, launch command failed) is ok = false, and the config
    % file is removed, also if the call is interrupted with Ctrl-C before the launch. The
    % unix commands are run as /bin/sh -c '...', whatever shell MATLAB's system() uses.
    % curl must be installed (on Windows, curl.exe from Windows 10 on); this is not checked,
    % as a check on every call is slow. If curl is missing the upload is silently lost, so
    % users must check for it once (see README.md). The Windows launch
    % (start /B with redirected input and output) is expected to let system() return at
    % once; that has not been checked on a Windows machine.
    %
    % In background mode ResponseTimeout becomes curl's --max-time, a limit on the whole
    % transfer, including the upload of the zip. DataTimeout is ignored.
    %
    % Deliberate catch-all: this runs inside long-running instrument and analysis code, and a
    % flaky network or bad config must never interrupt it. Every failure is reported as
    % result.ok = false instead.
    % The token is scrubbed from any message with cfg.scrub.
    %
    % Inputs
    % zipPath - path to the zip file to upload.
    % cfg - webupload.webConfig object. Anything else is reported as result.ok = false.
    % micID - microscope ID as returned by webupload.readRecipe. '' means the recipe had none.
    % source - 'acq' or 'analysis'.
    %
    % Inputs (optional param/val pairs)
    % 'ConnectTimeout'  - Seconds. Positive finite scalar that replaces
    %                     cfg.connectTimeout for this call only.
    % 'ResponseTimeout' - Seconds. Replaces cfg.responseTimeout for this call only.
    % 'DataTimeout'     - Seconds. Replaces cfg.dataTimeout for this call only. Short
    %                     values keep a call from blocking its caller for long when the
    %                     network is dead. Ignored with 'Background', true.
    % 'Background'      - Logical scalar, default false. True starts a detached curl and
    %                     returns at once (see above).
    % 'Launcher'        - Hidden, for tests: function handle [status, out] = launcher(cmd)
    %                     that runs a shell command. Default @system.
    % 'IsPC'            - Hidden, for tests: logical, which platform's commands to build.
    %                     Default ispc.
    %
    % Outputs
    % result - structure with fields ok, httpStatus, message and background. httpStatus is NaN
    %          if no response arrived, and always for a background upload. background is true
    %          only when a background upload was started, with message 'Upload started in
    %          background; outcome not checked'.

    result = struct('ok', false, 'httpStatus', NaN, 'message', '', 'background', false);
    cfgIsValid = isa(cfg, 'webupload.webConfig') && isscalar(cfg) && isvalid(cfg);

    try
        if ~cfgIsValid
            error('webupload:badConfig', 'cfg must be a webupload.webConfig object.');
        end

        if isstring(micID) && isscalar(micID)
            micID = char(micID);
        end
        if isstring(source) && isscalar(source)
            source = char(source);
        end
        if isstring(zipPath) && isscalar(zipPath)
            zipPath = char(zipPath);
        end

        if ~ischar(micID) || ~(isrow(micID) || isempty(micID))
            error('webupload:badMicID', 'The microscope ID must be text.');
        elseif isempty(micID)
            error('webupload:badMicID', 'No microscope ID was found (SYSTEM.ID in the recipe).');
        elseif isempty(regexp(micID, webupload.serverLimits().idRegexp, 'once'))
            error('webupload:badMicID', ['The microscope ID "%s" is invalid: it must start with ', ...
                'a letter and contain only letters, digits, "_" and "-".'], micID);
        end
        if ~(ischar(source) && ismember(source, {'acq', 'analysis'}))
            shown = ['a value of class ' class(source)];
            if ischar(source)
                shown = ['"' source '"'];
            end
            error('webupload:badSource', 'source must be ''acq'' or ''analysis'', not %s.', shown);
        end

        params = inputParser;
        params.FunctionName = 'webupload.postZip';
        params.addParameter('ConnectTimeout', cfg.connectTimeout, webupload.webConfig.isSeconds)
        params.addParameter('ResponseTimeout', cfg.responseTimeout, webupload.webConfig.isSeconds)
        params.addParameter('DataTimeout', cfg.dataTimeout, webupload.webConfig.isSeconds)
        isLogicalScalar = @(x) isscalar(x) && (islogical(x) || (isnumeric(x) && isreal(x) && ~isnan(x)));
        params.addParameter('Background', false, isLogicalScalar)
        params.addParameter('IsPC', ispc, @(x) isscalar(x) && islogical(x))
        params.addParameter('Launcher', @system, @(x) isa(x, 'function_handle') && isscalar(x))
        params.parse(varargin{:});
        background = logical(params.Results.Background);
        opts = makeOptions(params.Results.ConnectTimeout, params.Results.ResponseTimeout, ...
                           params.Results.DataTimeout);

        if ~isfile(zipPath)
            error('webupload:noZip', 'Zip file not found: %s', zipPath);
        end

        if background
            result = startBackgroundUpload(cfg, micID, source, zipPath, params.Results);
            result.message = cfg.scrub(result.message);
            return
        end

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % Build and send the request. The multipart body is built in memory, not streamed
        % from a MultipartFormProvider, so that the request carries a Content-Length (see
        % buildMultipart for why).
        [payload, contentType] = buildMultipart(cfg, micID, source, zipPath);
        body = matlab.net.http.MessageBody();
        body.Payload = payload; % raw bytes; setting Data instead would be converted by Content-Type
        req = matlab.net.http.RequestMessage('POST', [cfg.authHeader, contentType], body);

        % Send the request to the server
        resp = req.send(cfg.url, opts);

        result = webupload.interpretResponse(double(resp.StatusCode), resp.Body.Data);
        result.background = false;
    catch err
        result.message = err.message;
    end

    if cfgIsValid
        result.message = cfg.scrub(result.message);
    end
end % postZip


function result = startBackgroundUpload(cfg, micID, source, zipPath, settings)
    % Write the curl config and start curl detached; error if that fails
    %
    % function result = webupload.postZip>startBackgroundUpload(cfg, micID, source, zipPath, settings)
    %
    % Purpose
    % The 'Background' branch of postZip, run after the arguments have been checked. Writes
    % the config file, and runs the command from
    % webupload.backgroundCommand. The config file holds the token, so a guard deletes it
    % if anything fails or the call is interrupted; the guard is disarmed as soon as the
    % launch has succeeded, when the launched command becomes responsible for it. Errors
    % propagate to postZip, which reports them. The zip is never deleted here: on success
    % the launched command deletes it, on failure the caller does.
    %
    % Inputs
    % cfg, micID, source, zipPath - as for postZip, already validated.
    % settings - postZip's parsed parameters: ConnectTimeout, ResponseTimeout, IsPC and Launcher.
    %
    % Outputs
    % result - structure as returned by postZip, with ok and background true.

    isPC = settings.IsPC;
    if isPC
        nullDevice = 'NUL';
    else
        nullDevice = '/dev/null';
    end
    launcher = settings.Launcher;

    text = webupload.curlConfigText(cfg, micID, source, zipPath, ...
        settings.ConnectTimeout, settings.ResponseTimeout, nullDevice);
    cfgPath = [tempname, '.curlcfg'];
    guard = webupload.CleanupGuard(@() deleteIfFile(cfgPath));
    writePrivateFile(cfgPath, text);

    cmd = webupload.backgroundCommand(cfgPath, zipPath, isPC);
    if ~isPC
        cmd = inBinSh(cmd);
    end
    status = launcher(cmd);
    if status ~= 0
        error('webupload:launchFailed', 'Starting curl failed (status %d).', status);
    end
    guard.disarm();

    result = struct('ok', true, 'httpStatus', NaN, ...
        'message', 'Upload started in background; outcome not checked', 'background', true);
end % startBackgroundUpload


function writePrivateFile(path, text)
    % Write text to a new file that only the current user can read (on unix)
    %
    % function webupload.postZip>writePrivateFile(path, text)
    %
    % Purpose
    % On unix the file is created by the shell under umask 077, so it never exists with wider
    % permissions than 600, and the result is checked. On Windows tempdir is already per user.
    % Errors if the file cannot be created, restricted or written; the caller deletes it.
    %
    % Inputs
    % path - where to write the file. Must not exist.
    % text - contents.

    if isunix
        [status, msg] = system(['umask 077; : > ', shellQuote(path)]);
        if status ~= 0
            error('webupload:configNotWritten', ...
                'Could not create the curl config file in %s: %s', tempdir, msg);
        end
        [~, attr] = fileattrib(path);
        if any([attr.GroupRead attr.GroupWrite attr.OtherRead attr.OtherWrite])
            error('webupload:configNotWritten', ...
                'The curl config file is not private; not using it.');
        end
    end
    fid = fopen(path, 'w', 'n', 'UTF-8'); % an existing file keeps its permissions
    if fid < 0
        error('webupload:configNotWritten', ...
            'Could not write the curl config file in %s.', tempdir);
    end
    % A truncated config could lose max-time, so a short write or failed close is an error
    nWritten = fprintf(fid, '%s', text);
    closeStatus = fclose(fid);
    if nWritten ~= numel(unicode2native(text, 'UTF-8')) || closeStatus ~= 0
        error('webupload:configNotWritten', ...
            'The curl config file was not written completely.');
    end
end % writePrivateFile


function opts = makeOptions(connectTimeout, responseTimeout, dataTimeout)
    % Build HTTPOptions with no redirects and the given timeouts
    %
    % function opts = webupload.postZip>makeOptions(connectTimeout, responseTimeout, dataTimeout)
    %
    % Purpose
    % MaxRedirects = 0 is set unconditionally because it protects the bearer token. The
    % ResponseTimeout and DataTimeout properties are not present in every MATLAB release;
    % if one is missing a warning 'webupload:postZip:noTimeout' is issued and that timeout
    % is not applied.
    %
    % Inputs
    % connectTimeout, responseTimeout, dataTimeout - seconds.
    %
    % Outputs
    % opts - matlab.net.http.HTTPOptions object.

    opts = matlab.net.http.HTTPOptions();
    opts.MaxRedirects = 0; % security-relevant: set unconditionally
    opts.ConnectTimeout = connectTimeout;

    % These two names vary by release; warn rather than fail if absent
    optional = {'ResponseTimeout', responseTimeout; 'DataTimeout', dataTimeout};
    for ii = 1:size(optional, 1)
        if isprop(opts, optional{ii, 1})
            opts.(optional{ii, 1}) = optional{ii, 2};
        else
            warning('webupload:postZip:noTimeout', ...
                ['HTTPOptions has no %s in this MATLAB release; ', ...
                'that timeout is not applied.'], optional{ii, 1});
        end
    end %for
end % makeOptions


function [payload, contentType] = buildMultipart(cfg, micID, source, zipPath)
    % Build a multipart/form-data body in memory with the IDs, the source and the zip
    %
    % function [payload, contentType] = webupload.postZip>buildMultipart(cfg, micID, source, zipPath)
    %
    % Purpose
    % Streaming the body with matlab.net.http.io.MultipartFormProvider gives a request with no
    % Content-Length (chunked), and the brainsaw server's PHP (FastCGI) then receives none of
    % the form fields. Building the bytes here lets MATLAB send the length. The layout follows
    % RFC 7578: 'site_id', 'microscope_id' and 'source' text parts, then a 'data' file part
    % (application/zip), each preceded by a boundary line, with CRLF line endings, and a closing boundary.
    %
    % Inputs
    % cfg     - webupload.webConfig object; its siteID is sent.
    % micID   - microscope ID to send.
    % source  - 'acq' or 'analysis'.
    % zipPath - Path to the zip file to send. It is read into memory.
    %
    % Outputs
    % payload     - uint8 row vector holding the whole request body.
    % contentType - matlab.net.http.field.ContentTypeField with the multipart boundary.

    % A random boundary that will not occur in the zip by accident. It comes from Java's UUID
    % so that uploading never changes the state of MATLAB's global random number generator.
    boundary = ['----BrainsawBoundary', strrep(char(java.util.UUID.randomUUID().toString()), '-', '')];

    fid = fopen(zipPath, 'r');
    if fid < 0
        error('webupload:noZip', 'Could not open zip file: %s', zipPath);
    end
    closer = onCleanup(@() fclose(fid));
    zipBytes = fread(fid, Inf, '*uint8')';
    clear closer

    textFields = {'site_id', cfg.siteID; 'microscope_id', micID; 'source', source};
    textParts = '';
    for ii = 1:size(textFields, 1)
        textParts = [textParts, sprintf( ...
            '--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n', ...
            boundary, textFields{ii, :})]; %#ok<AGROW>
    end
    siteField = unicode2native(textParts, 'UTF-8');
    fileHeader = unicode2native(sprintf( ...
        ['--%s\r\nContent-Disposition: form-data; name="data"; filename="system_data.zip"\r\n', ...
         'Content-Type: application/zip\r\n\r\n'], boundary), 'UTF-8');
    closing = unicode2native(sprintf('\r\n--%s--\r\n', boundary), 'UTF-8');

    payload = [siteField, fileHeader, zipBytes, closing];
    contentType = matlab.net.http.field.ContentTypeField(['multipart/form-data; boundary=', boundary]);
end % buildMultipart
