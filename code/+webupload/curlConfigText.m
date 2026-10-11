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
    % redirects unless told to, which keeps the token from being sent elsewhere. 'proto' limits
    % curl to the scheme of the url (webConfig allows plain http only for localhost). 'http1.1'
    % and an empty Expect header keep the request to one plain POST, as the in-process one is;
    % that this gives the same Content-Length behaviour on the production server (FastCGI) has
    % only been checked against a local listener.
    %
    % Timeouts: max-time limits the whole transfer, so it covers the upload of the zip as well
    % as the reply. There is no equivalent of DataTimeout, so that option is ignored here.
    %
    % The text contains the token, so write it to a file only the user can read, and delete
    % it afterwards. Values are double-quoted with \ and " escaped. The zip path is escaped
    % twice: once for curl's form parser, which treats the quoted file name specially, and
    % once for the config file. Control characters in any value are refused
    % (webupload:badConfigValue, naming the field but not showing it, since it may be the
    % token), because they would end the config line. The text fields use form-string, so an
    % @ or < in a value is
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
    names = {'url', 'authorization header', 'site ID', 'microscope ID', 'source', ...
             'zip path', 'null device'};
    for ii = 1:numel(values)
        if any(values{ii} < 32)
            error('webupload:badConfigValue', 'The %s contains a control character.', names{ii});
        end
    end
    if startsWith(url, 'https://')
        proto = '=https';
    elseif ~isempty(regexp(url, '^http://(localhost|127\.0\.0\.1)(:\d+)?(/|$)', 'once'))
        proto = '=http'; % the same exception as webConfig: plain http only for local testing
    else
        error('webupload:badConfigValue', 'The url must be https (http only for localhost).');
    end

    formFile = ['data=@"', backslashEscape(zipPath), ...
                '";type=application/zip;filename=system_data.zip'];
    lines = { ...
        ['url = ', configQuote(url)]
        ['header = ', configQuote(['Authorization: ', authValue])]
        ['form-string = ', configQuote(['site_id=', siteID])]
        ['form-string = ', configQuote(['microscope_id=', micID])]
        ['form-string = ', configQuote(['source=', source])]
        ['form = ', configQuote(formFile)]
        ['proto = ', configQuote(proto)]
        'http1.1'
        'header = "Expect:"'
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
