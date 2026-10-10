function s = stageSpec
    % Staged file names and the other fixed settings of the stage folder, defined once
    %
    % function s = webupload.stageSpec
    %
    % Purpose
    % The Names are the exact file names the server keeps (webupload.allowedNames); the
    % recipe is always staged as recipe.yml whatever the extension of the source. Used by
    % stageFiles and by the tests.
    %
    % Outputs
    % s - Structure with fields Names (Main, Thumbnail, Montage, MontageThumbnail, Recipe, Log), JpegQuality,
    %     ThumbnailWidth and PartSuffix. Thumbnail is the small copy of the Main image that
    %     the server shows on the cards, ThumbnailWidth pixels wide; MontageThumbnail is the same for the Montage. PartSuffix marks
    %     in-progress files, which the server does not keep.

    s.Names.Main = 'LastCompleteSection.jpg';
    s.Names.Thumbnail = 'tile_thumbnail.jpg';
    s.Names.Montage = 'montage.jpg';
    s.Names.MontageThumbnail = 'montage_thumbnail.jpg';
    s.Names.Recipe = 'recipe.yml';
    s.Names.Log = 'acqLog.txt';
    s.JpegQuality = 85;
    s.ThumbnailWidth = 500;
    s.PartSuffix = '.part';
end % stageSpec
