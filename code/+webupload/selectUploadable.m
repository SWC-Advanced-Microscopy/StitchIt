function names = selectUploadable(dirPath)
    % File names (not paths) in dirPath that the server will keep
    %
    % function names = webupload.selectUploadable(dirPath)
    %
    % Purpose
    % Returns a cell row; empty when nothing matches. Only files whose name is exactly one of
    % webupload.allowedNames are kept; subfolders and every other name are skipped.
    %
    % Inputs
    % dirPath - path to the folder to scan.
    %
    % Outputs
    % names - cell row of file names.

    d = dir(dirPath);
    names = {d(~[d.isdir]).name};
    names = names(ismember(names, webupload.allowedNames()));
end % selectUploadable
