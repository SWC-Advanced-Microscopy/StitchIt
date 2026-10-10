function result = stageFiles(img,recipePath,logPath,stageDir,varargin)
    % Assemble the files for one web-preview upload in stageDir
    %
    % function result = webupload.stageFiles(img,recipePath,logPath,stageDir,'Param1',val1,...)
    %
    % Purpose
    % Files written, under the names the server keeps (webupload.stageSpec,
    % webupload.allowedNames):
    %   LastCompleteSection.jpg   from img, if given
    %   tile_thumbnail.jpg        made from img, if given (see THUMBNAIL below)
    %   montage.jpg               from the 'Montage' image, if given
    %   montage_thumbnail.jpg     made from the 'Montage' image, if given (as the thumbnail above)
    %   recipe.yml                copy of the recipe, whatever the source extension
    %   acqLog.txt                copy of the log
    % status.json is written separately, by webupload.writeStatus.
    %
    % An image (img or 'Montage') is one of: the literal [] (none; a previously staged one
    % is deleted, after the new files are in place, so it can never go up with a new
    % recipe), a numeric array (converted with
    % webupload.toUint8 and written as a jpg) or the path of a jpg file (copied as is).
    % Any other empty array is an error, as is anything else, a path that is not an
    % existing .jpg/.jpeg file. All of these throw before stageDir is touched, 'ClearStage' included.
    %
    % THUMBNAIL: the server shows tile_thumbnail.jpg on the cards instead of the full image.
    % It is the main image shrunk to stageSpec's ThumbnailWidth (500 px) wide, aspect ratio
    % kept, with imresize (Image Processing Toolbox). An
    % image that is already narrower is not enlarged. A jpg path is read with imread. It is
    % only ever staged together with the image it was made from: when img is [], or the
    % thumbnail cannot be made (warning 'webupload:stageFiles:thumbnailFailed', not a stage
    % failure), or the image is not renamed into place, any staged thumbnail is deleted.
    % The server then shows the full image on the card. The montage thumbnail follows the same
    % rules with the montage.
    %
    % FAILURE POLICY: a preview must never abort an acquisition, so any error in reading
    % a recipe to compare sample IDs counts as "not the same sample", and
    %  - a log that is missing, not a path, or fails to copy only WARNS. The previously
    %    staged log is kept (result.logKept) only if the previously staged recipe has the
    %    same, non-empty sample ID as the new one; otherwise it is deleted, so an old
    %    sample's log is never uploaded with a new recipe;
    %  - a recipe that is missing, not a path, or fails to copy WARNS and the previously
    %    staged recipe is deleted, because a recipe left over from another sample must
    %    never be uploaded with new files;
    %  - file-system failures while staging (cannot create, clear or write stageDir, cannot
    %    rename or delete files) warn 'webupload:stageFiles:stageFailed' and set
    %    result.stageOk = false; the stage may then be incomplete.
    %
    % FILE HANDLING: new files are written under '.part' names (matched by no server
    % name) and then renamed into place, so a zip taken meanwhile does not see a
    % half-written file. The names <staged name>.part (for example
    % LastCompleteSection.jpg.part) are reserved for this and are deleted when the call
    % ends; other files are left alone, as the server ignores them. Staged files whose
    % source was not given or not obtained are deleted once the files that were obtained
    % are in place, by their fixed names. So the sources must not live in the stage
    % folder: a source with a staged name there can be overwritten or deleted.
    % Sources outside it are only read.
    %
    % Inputs
    % img        - [], a numeric HxW or HxWx3 image, or the path of a jpg file.
    % recipePath - Path to the recipe file.
    % logPath    - Path to the acquisition log file.
    % stageDir   - Non-empty text scalar. Folder to assemble the files in. Created if
    %              absent.
    %
    % Inputs (optional param/val pairs)
    % 'Montage' - As img, staged as montage.jpg. Default is [] (none).
    % 'ClearStage' - Logical scalar. If true, delete stageDir and everything in it, after
    %             the arguments have been checked. Default is false.
    %
    % Outputs
    % result - Structure with fields:
    %   files         - full paths renamed into place.
    %   mainStaged    - logical.
    %   thumbnailStaged - logical.
    %   montageThumbnailStaged - logical.
    %   montageStaged - logical.
    %   recipeStaged  - logical.
    %   logStaged     - logical.
    %   logKept       - logical. No new log was staged and the previous one was kept.
    %   recipeSource  - path of the recipe used, or ''.
    %   stageOk       - logical.
    %
    % See also: webupload.toUint8, webupload.stageSpec, webupload.updateSectionImage


    narginchk(4,Inf)

    isText = (ischar(stageDir) && isrow(stageDir)) || (isstring(stageDir) && isscalar(stageDir));
    if ~isText || ~(strlength(stageDir)>0)
        error('webupload:stageFiles:badStageDir', ...
            'stageDir must be a non-empty text scalar.')
    end
    stageDir = char(stageDir);

    params = inputParser;
    params.FunctionName = 'webupload.stageFiles';
    params.CaseSensitive = false;
    params.addParameter('Montage', [], @(x) true)
    params.addParameter('ClearStage', false, @(x) islogical(x) && isscalar(x))
    params.parse(varargin{:});

    % Pure conversion first: programming errors throw here, before any I/O.
    mainSrc = imageSource(img);
    montageSrc = imageSource(params.Results.Montage);

    result = struct('files', {{}}, 'mainStaged', false, 'thumbnailStaged', false, ...
                    'montageStaged', false, 'montageThumbnailStaged', false, ...
                    'recipeStaged', false, 'logStaged', false, 'logKept', false, ...
                    'recipeSource', '', 'stageOk', true);
    try
        if params.Results.ClearStage
            try
                webupload.clearStageDir(stageDir);
            catch ME
                error('webupload:stageFiles:ioFailure','clear folder: %s', ME.message)
            end %try
        end
        result = stageOnDisk(result,mainSrc,montageSrc,recipePath,logPath,stageDir);
    catch ME
        % Only failures raised by our own file-system wrappers are tolerated
        if ~strcmp(ME.identifier,'webupload:stageFiles:ioFailure')
            rethrow(ME);
        end
        warning('webupload:stageFiles:stageFailed', ...
            'Staging in "%s" failed: %s', stageDir, ME.message)
        result.stageOk = false;
    end %try
end % stageFiles


function src = imageSource(img)
    % Validate an image argument and reduce it to what stageOnDisk writes
    %
    % function src = webupload.stageFiles>imageSource(img)
    %
    % Inputs
    % img   - The literal [], a numeric image or the path of a jpg file.
    %
    % Outputs
    % src - [] for no image, a uint8 image, or the char path of an existing jpg file.
    %
    % Errors
    % 'webupload:stageFiles:badImage' if img is none of the above, or a path that is not
    % an existing .jpg/.jpeg file. Errors from webupload.toUint8 are passed on.

    if isa(img,'double') && isequal(size(img),[0 0])
        src = [];
        return
    end
    if isnumeric(img)
        src = webupload.toUint8(img);
        return
    end

    isText = (ischar(img) && isrow(img)) || (isstring(img) && isscalar(img));
    if ~isText || isempty(regexpi(char(img),'\.jpe?g$','once')) || ~isfile(char(img))
        error('webupload:stageFiles:badImage', ...
            'An image must be [], a numeric array or the path of an existing .jpg file.')
    end
    src = char(img);
end % imageSource


function result = stageOnDisk(result,mainSrc,montageSrc,recipePath,logPath,stageDir)
    % Write the part files, rename them into place and delete the stale ones
    %
    % function result = webupload.stageFiles>stageOnDisk(result,mainSrc,montageSrc,recipePath,logPath,stageDir)
    %
    % Purpose
    % The file-system half of stageFiles. Resolves the recipe and log sources first; an
    % unusable source only warns. Then writes the images and copies the sources under
    % '.part' names and renames each into place. Finally deletes the staged files of the
    % kinds that were not obtained in this call (no image given, recipe not copied).
    %
    % File-system failures while writing are thrown as 'webupload:stageFiles:ioFailure'
    % and handled by stageFiles. Failures to rename or to delete stale files warn
    % 'webupload:stageFiles:stageFailed' and set result.stageOk to false.
    %
    % Inputs
    % result   - Result structure from stageFiles, to be filled in.
    % mainSrc  - Main image from imageSource.
    % montageSrc - Montage image from imageSource.
    % recipePath - Path to the recipe file.
    % logPath    - Path to the acquisition log file.
    % stageDir   - Char path to the stage folder. Created if absent.
    %
    % Outputs
    % result - The input with files, the *Staged flags and recipeSource filled in, and
    %          stageOk set to false if anything failed.

    spec = webupload.stageSpec;
    if ~isfolder(stageDir)
        [ok,msg] = mkdir(stageDir);
        if ~ok
            error('webupload:stageFiles:ioFailure','create folder "%s": %s', stageDir, msg)
        end
    end

    [recipeFile,recipeProblem] = resolveFile(recipePath,'recipePath');
    if ~isempty(recipeProblem)
        warning('webupload:stageFiles:missingRecipe', ...
            'Recipe not staged (%s); any previously staged recipe is removed.', recipeProblem)
    end
    [logFile,logProblem] = resolveFile(logPath,'logPath');

    % Decided before the recipe is replaced
    keepLog = sameSample(fullfile(stageDir,spec.Names.Recipe),recipeFile);
    if ~isempty(logProblem)
        fate = 'any previous log is removed';
        if keepLog && isfile(fullfile(stageDir,spec.Names.Log))
            fate = 'the previous log is kept';
        end
        warning('webupload:stageFiles:missingLog', ...
            'Acq log not staged (%s); %s.', logProblem, fate)
    end

    % Delete only the in-progress files this call can create
    partPaths = fullfile(stageDir,strcat(struct2cell(spec.Names),spec.PartSuffix));
    cleanup = onCleanup(@() cellfun(@(f) delete(f), partPaths(cellfun(@isfile,partPaths))));

    parts = [imagePart(mainSrc,'Main',stageDir,spec), ...
             thumbnailPart(mainSrc,'Thumbnail',stageDir,spec), ...
             imagePart(montageSrc,'Montage',stageDir,spec), ...
             thumbnailPart(montageSrc,'MontageThumbnail',stageDir,spec), ...
             copyPart(recipeFile,'Recipe',stageDir,spec), ...
             copyPart(logFile,'Log',stageDir,spec)];

    failures = {};
    for kk = 1:numel(parts)
        final = fullfile(stageDir,spec.Names.(parts(kk).kind));
        [ok,msg] = movefile(parts(kk).part,final,'f');
        if ok
            result.files{end+1} = final;
        else
            failures{end+1} = sprintf('could not rename "%s" to "%s": %s', ...
                                parts(kk).part, final, msg); %#ok<AGROW>
        end
    end %for

    % The log may fall back to the previous one, for the same sample only; the others may
    % not. A thumbnail is only kept beside the image it was made from.
    staged = result.files;
    mainStaged = ismember(fullfile(stageDir,spec.Names.Main),staged);
    montageStaged = ismember(fullfile(stageDir,spec.Names.Montage),staged);
    for kind = fieldnames(spec.Names)'
        final = fullfile(stageDir,spec.Names.(kind{1}));
        if strcmp(kind{1},'Log') && keepLog
            continue
        end
        stale = ~ismember(final,staged) || (strcmp(kind{1},'Thumbnail') && ~mainStaged) ...
                || (strcmp(kind{1},'MontageThumbnail') && ~montageStaged);
        if stale && isfile(final)
            delete(final)
            if isfile(final)
                failures{end+1} = sprintf('could not delete stale file %s', final); %#ok<AGROW>
            end
        end
    end %for

    result.mainStaged = mainStaged;
    result.thumbnailStaged = mainStaged && isfile(fullfile(stageDir,spec.Names.Thumbnail));
    result.montageStaged = montageStaged;
    result.montageThumbnailStaged = montageStaged && isfile(fullfile(stageDir,spec.Names.MontageThumbnail));
    result.recipeStaged = ismember(fullfile(stageDir,spec.Names.Recipe),staged);
    result.logStaged = ismember(fullfile(stageDir,spec.Names.Log),staged);
    result.logKept = ~result.logStaged && isfile(fullfile(stageDir,spec.Names.Log));
    if result.recipeStaged
        result.recipeSource = recipeFile;
    end

    if ~isempty(failures)
        result.stageOk = false;
        warning('webupload:stageFiles:stageFailed', ...
            'Staging in "%s" incomplete: %s', stageDir, strjoin(failures,'; '))
    end
end % stageOnDisk


function tf = sameSample(stagedRecipe,newRecipe)
    % True if two recipe files name the same, non-empty sample ID
    %
    % function tf = webupload.stageFiles>sameSample(stagedRecipe,newRecipe)
    %
    % Inputs
    % stagedRecipe - Path of the recipe staged by an earlier call; may not exist.
    % newRecipe    - Path of the new recipe, or '' if there is none.
    %
    % Outputs
    % tf - false if either file is missing or unreadable, or either has no sample ID.

    tf = false;
    if ~isempty(newRecipe) && isfile(stagedRecipe)
        try
            [~,oldSample] = webupload.readRecipe(stagedRecipe);
            [~,newSample] = webupload.readRecipe(newRecipe);
            tf = ~isempty(oldSample) && strcmp(oldSample,newSample);
        catch
            % Deliberate: an unreadable recipe must not abort staging; the log is dropped
        end %try
    end
end % sameSample


function [file,problem] = resolveFile(p,label)
    % Check that a source path is an existing file
    %
    % function [file,problem] = webupload.stageFiles>resolveFile(p,label)
    %
    % Inputs
    % p     - Any value; should be the path of a file.
    % label - Name of the argument, for the problem text.
    %
    % Outputs
    % file    - Char path, or '' if p is unusable.
    % problem - Human-readable reason if file is empty, otherwise ''.

    file = '';
    problem = '';
    isPath = (ischar(p) && isrow(p) && ~isempty(p)) || (isstring(p) && isscalar(p) && strlength(p)>0);
    if ~isPath
        problem = sprintf('%s is not a non-empty text path', label);
    elseif isfile(char(p))
        file = char(p);
    else
        problem = sprintf('"%s" is not an existing file', char(p));
    end
end % resolveFile


function p = imagePart(src,kind,stageDir,spec)
    % Write or copy an image to its '.part' name
    %
    % function p = webupload.stageFiles>imagePart(src,kind,stageDir,spec)
    %
    % Purpose
    % The file is renamed to its final name later. Errors with
    % 'webupload:stageFiles:ioFailure' (which stageFiles turns into a warning) if the write
    % or copy fails.
    %
    % Inputs
    % src      - [] (nothing to do), a uint8 image to write, or the path of a jpg to copy.
    % kind     - 'Main' or 'Montage': the field of spec.Names giving the final name.
    % stageDir - Char path to the stage folder.
    % spec     - Structure from webupload.stageSpec.
    %
    % Outputs
    % p - Structure with fields kind and part (full path written), as used by
    %     stageOnDisk. [] if src was empty.

    p = [];
    if isempty(src)
        return
    end

    part = fullfile(stageDir,[spec.Names.(kind) spec.PartSuffix]);
    try
        if ischar(src)
            [ok,msg] = copyfile(src,part,'f');
            if ~ok
                error('webupload:stageFiles:copyFailed','%s',msg)
            end
        else
            % Explicit format: '.part' is not an image extension
            imwrite(src,part,'jpg','Quality',spec.JpegQuality);
        end
    catch ME
        error('webupload:stageFiles:ioFailure','write "%s": %s', part, ME.message)
    end %try
    p = struct('kind', kind, 'part', part);
end % imagePart


function p = thumbnailPart(src,kind,stageDir,spec)
    % Write the thumbnail of an image to its '.part' name
    %
    % function p = webupload.stageFiles>thumbnailPart(src,kind,stageDir,spec)
    %
    % Purpose
    % The thumbnail is a convenience: if it cannot be made (an unreadable jpg, a failed
    % write) this warns 'webupload:stageFiles:thumbnailFailed' and returns [], so the
    % caller deletes any old thumbnail and the server shows the full image instead.
    %
    % Inputs
    % src      - [] (nothing to do), the uint8 image, or the path of the jpg.
    % kind     - 'Thumbnail' (of the main image) or 'MontageThumbnail': the field of
    %            spec.Names giving the final name.
    % stageDir - Char path to the stage folder.
    % spec     - Structure from webupload.stageSpec.
    %
    % Outputs
    % p - Structure with fields kind and part (full path written), as used by
    %     stageOnDisk. [] if src was empty or the thumbnail could not be made.

    p = [];
    if isempty(src)
        return
    end

    part = fullfile(stageDir,[spec.Names.(kind) spec.PartSuffix]);
    try
        if ischar(src)
            src = imread(src);
        end
        if ~isa(src,'uint8')
            src = webupload.toUint8(src);
        end
        if size(src,2) > spec.ThumbnailWidth   % never enlarge
            src = imresize(src,[NaN spec.ThumbnailWidth]);
        end
        imwrite(src,part,'jpg','Quality',spec.JpegQuality);
    catch ME
        warning('webupload:stageFiles:thumbnailFailed', ...
            '%s not staged (%s); the server will show the full image.', spec.Names.(kind), ME.message)
        return
    end %try
    p = struct('kind', kind, 'part', part);
end % thumbnailPart


function p = copyPart(src,kind,stageDir,spec)
    % Copy a recipe or log to its '.part' name
    %
    % function p = webupload.stageFiles>copyPart(src,kind,stageDir,spec)
    %
    % Purpose
    % A failed copy warns 'webupload:stageFiles:copyFailed' and returns [], so that the
    % caller treats the file as not obtained; it is not a stage failure.
    %
    % Inputs
    % src      - Path of the file to copy, or '' if there is nothing to copy.
    % kind     - 'Recipe' or 'Log': the field of spec.Names giving the final name.
    % stageDir - Char path to the stage folder.
    % spec     - Structure from webupload.stageSpec.
    %
    % Outputs
    % p - Structure with fields kind and part (full path written). [] if src was empty
    %     or the copy failed.

    p = [];
    if isempty(src)
        return
    end

    part = fullfile(stageDir,[spec.Names.(kind) spec.PartSuffix]);
    try
        [ok,msg] = copyfile(src,part,'f');
    catch ME
        ok = false;
        msg = ME.message;
    end %try

    if ~ok
        warning('webupload:stageFiles:copyFailed', 'Could not copy "%s": %s', src, msg)
        return
    end
    p = struct('kind', kind, 'part', part);
end % copyPart
