function names = allowedNames()
    % File names (exact, case-sensitive) the brainsaw server keeps
    %
    % function names = webupload.allowedNames()
    %
    % Purpose
    % Copy of allowedNames in the shared contract (upload_core/tests/upload_contract.json); the
    % server's BS_ZIP_ALLOWED_NAMES must match it, and a test checks this copy against it.
    %
    % Outputs
    % names - cell row of the seven file names the server extracts from an upload.

    names = {'LastCompleteSection.jpg', 'tile_thumbnail.jpg', 'montage.jpg', 'montage_thumbnail.jpg', 'recipe.yml', 'acqLog.txt', 'status.json'};
end % allowedNames
