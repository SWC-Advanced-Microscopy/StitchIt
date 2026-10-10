function result = interpretResponse(httpStatus, body)
    % Turn an HTTP status and decoded body into a result structure
    %
    % function result = webupload.interpretResponse(httpStatus, body)
    %
    % Purpose
    % Success needs both HTTP 200 and {"status":"ok"} in the body. Pure function, so it is
    % tested without a network.
    %
    % Inputs
    % httpStatus - numeric HTTP status code.
    % body - decoded JSON structure, or anything else (e.g. an HTML error page), which is
    %        tolerated.
    %
    % Outputs
    % result - structure with fields ok, httpStatus and message.

    result = struct('ok', false, 'httpStatus', double(httpStatus), 'message', '');

    isJson = isstruct(body) && isscalar(body);
    serverStatus = '';
    if isJson && isfield(body, 'status') && ischar(body.status)
        serverStatus = body.status;
    end
    if isJson && isfield(body, 'message') && ischar(body.message)
        result.message = body.message;
    end

    result.ok = (httpStatus == 200) && strcmp(serverStatus, 'ok');
    if isempty(result.message)
        if httpStatus >= 300 && httpStatus < 400
            result.message = sprintf(['server redirected (HTTP %d); redirects are not ', ...
                'followed, check the url in the config'], httpStatus);
        elseif result.ok
            result.message = 'uploaded';
        else
            result.message = sprintf('upload failed (HTTP %d)', httpStatus);
        end
    end
end % interpretResponse
