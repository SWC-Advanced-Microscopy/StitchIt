function clearStageDir(folder)
    % Delete a managed stage folder recursively. A folder that is absent is fine
    %
    % function webupload.clearStageDir(folder)
    %
    % Purpose
    % Removes folder and everything in it. Only pass folders obtained from
    % webupload.stageDirFor, because the delete is recursive.
    %
    % Inputs
    % folder - Non-empty text scalar: path of the stage folder to remove, e.g.
    %          webupload.clearStageDir(webupload.stageDirFor(cfg,micID,stageRoot,source))
    %
    % Errors
    % 'webupload:clearStageDir:badArgument' if folder is not a non-empty text scalar.
    % 'webupload:clearStageDir:failed' if the folder exists but cannot be removed.
    %
    % See also: webupload.stageDirFor, webupload.clearStage


    narginchk(1,1)
    isText = (ischar(folder) && isrow(folder)) || (isstring(folder) && isscalar(folder));
    if ~isText || ~(strlength(folder)>0)
        error('webupload:clearStageDir:badArgument', ...
            'folder must be a non-empty text scalar.')
    end

    folder = char(folder);
    if ~isfolder(folder)
        return
    end

    [ok,msg] = rmdir(folder,'s');
    if ~ok
        error('webupload:clearStageDir:failed', ...
            'could not clear stage folder "%s": %s', folder, msg)
    end
end % clearStageDir
