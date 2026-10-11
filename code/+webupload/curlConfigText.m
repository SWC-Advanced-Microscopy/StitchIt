function text = curlConfigText(cfg, micID, source, zipPath, connectTimeout, maxTime, nullDevice)
    % Text of a curl -K config file that uploads the zip, as postZip does in-process
    %
    % function text = webupload.curlConfigText(cfg, micID, source, zipPath, ...
    %                                           connectTimeout, maxTime, nullDevice)
    %
    % Purpose
    % Used by webupload.postZip for 'Background', true. The request is the same as the
    % in-process one: an Authorization: Bearer header (from cfg.authHeader, so the token is
    % not read here), form fields site_id, microscope_id and source, and the zip as 'data'.
    % curl builds the multipart body itself and sends a Content-Length, and does not follow
    % redirects unless told to, which keeps the token from being sent elsewhere.
    %
    % The text contains the token, so write it to a file only the user can read, and delete
    % it afterwards. Values are double-quoted with \ and " escaped. The zip path is escaped
    % twice: once for curl's form parser, which treats the quoted file name specially, and
    % once for the config file. Control characters in any value are refused, because they
    % would end the config line. The text fields use form-string, so an @ or < in a value is
    % never read as a file reference.
    %
    % Inputs
    % cfg            - webupload.webConfig object.
    % micID, source  - form field values, already validated by postZip.
    % zipPath        - path of the zip to send.
    % connectTimeout - seconds; curl --connect-timeout.
    % maxTime        - seconds; curl --max-time, the limit on the whole transfer.
    % nullDevice     - '/dev/null' or 'NUL', where curl's output goes.
    %
    % Outputs
    % text - the config file contents, one option per line, as a char row vector.

    % webConfig holds its text properties as strings; char keeps the escaping simple
    url = char(cfg.url);
    siteID = char(cfg.siteID);
    authValue = char(cfg.authHeader().Value);
    zipPath = char(zipPath);
    values = {url, authValue, siteID, micID, source, zipPath, nullDevice};
    for ii = 1:numel(values)
        if any(values{ii} < 32)
            % The offending value may be the token, so it is not shown
            error('webupload:badPath', 'Value %d of the curl config contains a control character.', ii);
        end
    end

    formFile = ['data=@"', backslashEscape(zipPath), '";type=application/zip;filename=system_data.zip'];
    lines = { ...
        ['url = ', configQuote(url)]
        ['header = ', configQuote(['Authorization: ', authValue])]
        ['form-string = ', configQuote(['site_id=', siteID])]
        ['form-string = ', configQuote(['microscope_id=', micID])]
        ['form-string = ', configQuote(['source=', source])]
        ['form = ', configQuote(formFile)]
        sprintf('connect-timeout = %g', connectTimeout)
        sprintf('max-time = %g', maxTime)
        ['output = ', configQuote(nullDevice)]
        'silent'};
    text = sprintf('%s\n', lines{:});
end % curlConfigText


function quoted = configQuote(value)
    % Double-quote a curl config value
    %
    % function quoted = webupload.curlConfigText>configQuote(value)

    quoted = ['"', backslashEscape(value), '"'];
end % configQuote


function escaped = backslashEscape(value)
    % Put a backslash before every \ and " (the escapes curl reads inside double quotes)
    %
    % function escaped = webupload.curlConfigText>backslashEscape(value)

    escaped = regexprep(value, '([\\"])', '\\$1');
end % backslashEscape
