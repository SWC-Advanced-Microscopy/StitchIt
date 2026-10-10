function d = stageDirFor(cfg,micID,stageRoot,source)
    % The managed stage folder <stageRoot>/brainsaw_webpreview/<siteID>/<micID>/<source>
    %
    % function d = webupload.stageDirFor(cfg,micID,stageRoot,source)
    %
    % Purpose
    % The one place that decides where staged files live. clearStage deletes the returned
    % folder recursively, so micID is checked against the server's ID rule here (siteID
    % was checked by webupload.webConfig); an ID such as '..' or 'a/b' is an error
    % (webupload:badMicID), and so is a source other than 'acq' or 'analysis'
    % (webupload:badSource). Callers pass a validated cfg and stageRoot. Each source has its
    % own folder because the server keeps the two sources apart.
    %
    % Inputs
    % cfg       - webupload.webConfig object.
    % micID     - Microscope ID, as returned by webupload.readRecipe.
    % stageRoot - Folder under which the stage folder lives (char or string).
    % source    - 'acq' or 'analysis'.
    %
    % Outputs
    % d - Char path to the stage folder.
    %
    % See also: webupload.clearStage, webupload.clearStageDir

    if ~(ischar(micID) && isrow(micID) && ~isempty(regexp(micID,webupload.serverLimits().idRegexp,'once')))
        error('webupload:badMicID', ...
            'The recipe has no usable microscope ID (SYSTEM.ID): "%s"', char(micID(:)'));
    end
    if ~(ischar(source) && ismember(source,{'acq','analysis'}))
        error('webupload:badSource', 'source must be ''acq'' or ''analysis'', not a %s.', class(source));
    end
    d = fullfile(char(stageRoot),'brainsaw_webpreview',cfg.siteID,micID,source);
end % stageDirFor
