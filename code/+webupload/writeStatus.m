function writeStatus(folder, finished)
    % Write status.json, {"finished": true|false}, into a folder
    %
    % function webupload.writeStatus(folder, finished)
    %
    % Purpose
    % The server requires status.json in every upload. It says whether the run the folder
    % belongs to has ended. An existing status.json is overwritten. Errors with
    % webupload:statusFailed if the file cannot be written (including a missing folder).
    %
    % Inputs
    % folder   - folder to write into.
    % finished - logical scalar. Errors with webupload:badStatus otherwise.

    if ~(islogical(finished) && isscalar(finished))
        error('webupload:badStatus', 'finished must be a logical scalar (true or false).');
    end

    text = jsonencode(struct('finished', finished));
    fid = fopen(fullfile(folder, 'status.json'), 'w');
    if fid < 0
        error('webupload:statusFailed', 'Could not write status.json in %s', folder);
    end
    written = fwrite(fid, text);
    closed = fclose(fid);
    if written ~= numel(text) || closed ~= 0
        error('webupload:statusFailed', 'Could not write status.json in %s', folder);
    end
end % writeStatus
