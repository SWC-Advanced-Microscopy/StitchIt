function result = updateSectionImage(img,varargin)
    % Stage and upload the web preview for one section or run. Never throws
    %
    % function result = webupload.updateSectionImage(img,'Param1',val1,...)
    %
    % Purpose
    % Sends the last completed section image to the web site, or marks the start or end
    % of an acquisition on it.
    %
    % This function is integrated into StitchIt, but can be called from BakingTray if
    % StitchIt is co-installed on the acquisition machine to allow BakingTray to also
    % send progress updates.
    %
    % Configuration and token file
    % For most users, the configuration file with the upload location, site ID, and
    % secret token should be in a file called "brainsaw_webpreview.json" somewhere in the
    % MATLAB path. It should appear in just one location.
    %
    %
    % Inputs (required)
    % img - can be:
    %   1. A numeric array  - converted with webupload.toUint8
    %   2. A path of a jpg  - copied in as LastCompleteSection.jpg.
    %   3. Empty, [] (no image). Any image staged by an earlier call is deleted (after
    %      the new files are in place, before the upload), so an old sample's image can
    %      never go up with a new recipe. Use [] for the call at the start of a run, so
    %      the page shows the new recipe.
    %
    %
    % Inputs (optional param/val pairs: config and metadata files)
    % If webupload.updateSectionImage is called from a section directory, it looks for the
    % local recipe file and acquisition log files. This should cover most use cases. These
    % files can optionally be specified here. Similarly, the webupload config file containing
    % the token will be found automatically from the path. But it can be defined here if
    % required.
    %
    % 'recipePath' - Path to the recipe file.
    % 'logPath'    - Path to the acquisition log file. If not given, the one acqLog_*.txt in the
    %             current folder. If there is none, or several, no log is sent.
    % 'cfg'        - webupload.webConfig object. If not supplied, the function looks for a
    %             file called "brainsaw_webpreview.json" and builds the object from that.
    %
    %
    % Inputs (optional param/val pairs: data source)
    % 'Source' (string, 'analysis' or 'acq')
    % This is an important setting. It tells the server whether the data come from the
    % acquisition or the analysis PC. Data sent by BakingTray ('acq') are treated as the
    % "ground truth": if BakingTray reports that the acquisition is finished, the
    % analysis PC cannot revert that. The default is 'analysis', because it is more
    % likely that people are setting this up for syncAndCrunch, and because we want
    % callers to opt in to the ground-truth state.
    %
    %
    % Inputs (optional param/val pairs: others)
    % 'Montage' is the all-depths-one-channel image that syncAndCrunch makes. Only the
    %    analysis PC may send this: with Source 'acq' the call fails and nothing is staged
    %    or sent. If empty it is not sent. Empty by default.
    %
    % 'Finished',true marks the run as ended in status.json. The server answers HTTP 429
    % to an upload that follows another from the same site, microscope and source within
    % its minimum interval. A Finished call must not be lost, so it waits that interval
    % plus one second and tries once more; other calls are not retried. The interval is
    % this client's copy of the server setting (webupload.serverLimits); a site that
    % raises it will answer the retry with another 429, and the Finished flag is lost
    % (ok is false, with the usual warning).
    %
    %
    % SUMMARY OF OPTIONAL ARGS
    % Inputs (optional param/val pairs)
    % 'recipePath' -  Path to recipe file
    % 'logPath'    -  Path to acquisition log file
    % 'cfg'        -  Config object
    % 'Source'     - 'analysis' (default) or 'acq'.
    % 'Montage'    - Image to stage as montage.jpg, as for img. Only with Source
    %                'analysis'. Default is [].
    % 'Finished'   - Logical scalar written to status.json. Default is false.
    % 'ConnectTimeout', 'ResponseTimeout', 'DataTimeout' - Seconds. Passed to the upload
    %                for this call only, and again to the retry (see webupload.postZip).
    %                Default is the config values.
    % 'Poster'     - Function handle with the zipAndPost signature,
    %                poster(folder,cfg,micID,source,...) -> struct(ok,httpStatus,message) with
    %                char message, where cfg is a webupload.webConfig object. Default is
    %                @webupload.zipAndPost; tests inject a fake.
    % 'ClearStage' - Logical scalar. If true, empty the stage folder first. Default is
    %                false.
    %
    % Outputs
    % result - Structure with fields:
    %   ok          - true if the upload succeeded.
    %   stage       - stageFiles result; [] if not reached.
    %   post        - struct with ok, httpStatus and message.
    %   stageDir    - '' if not reached; a char path built from StageRoot.
    %   recipeFresh - this call staged a new recipe. If not, nothing is uploaded.
    %   logFresh    - this call staged a new log.
    %   stale       - either of the above is false after staging. A notice
    %                 'webupload:updateSectionImage:stale' names the file when the
    %                 upload otherwise succeeded.
    %   error       - scrubbed MException; [] on success.
    %
    %
    % NOTE
    % Deliberate catch-all: The acquisition process must never be interrupted by the
    % preview image upload. Every failure inside the call (config, image or option problems,
    % staging, network, a throwing poster) is turned into a warning
    % 'webupload:updateSectionImage:failed' ("id: message") and result.ok = false. The
    % warning call itself is guarded, so warning('error',...) settings cannot make this
    % function throw. Errors in the arguments (including a cfg that is not a valid
    % webConfig, or no recipe, log or config file being found) are caught too, but a
    % variable that does not exist in the CALLER is an error MATLAB raises before this
    % function runs, and cannot be caught here.
    %
    % See also: webupload.clearStage, webupload.stageFiles, webupload.zipAndPost


    % ---
    % pre-define the output structure
    result = struct('ok', false, 'stage', [], ...
        'post', struct('ok',false,'httpStatus',NaN,'message',''), ...
        'stageDir', '', 'recipeFresh', false, 'logFresh', false, 'stale', false, ...
        'error', []);
    caught = [];
    cfg = [];

    % ---
    % Parse the input arguments

    % Define anonymous functions for testing input args
    % true if x is a char row vector or string scalar with at least one character.
    isNonEmptyText = @(x) ((ischar(x) && isrow(x)) || (isstring(x) && isscalar(x))) && strlength(x)>0;

    % true if x is a logical scalar or a real, non-NaN numeric scalar.
    isLogicalScalar = @(x) isscalar(x) && (islogical(x) || (isnumeric(x) && isreal(x) && ~isnan(x)));

    % true if x is [] (not given) or a positive finite scalar number.
    isTimeout = @(x) isnumeric(x) && (isempty(x) || (isscalar(x) && isreal(x) && isfinite(x) && x>0));


    params = inputParser;
    params.FunctionName = 'webupload.updateSectionImage';
    params.CaseSensitive = false;


    params.addParameter('cfg', [], @(x) isempty(x) || (isa(x,'webupload.webConfig') && isscalar(x) && isvalid(x)))
    params.addParameter('recipePath', [], @(x) isempty(x) || ischar(x))
    params.addParameter('logPath', [], @(x) isempty(x) || ischar(x))

    params.addParameter('Source', 'analysis', @(x) isNonEmptyText(x) && ismember(char(x),{'acq','analysis'}))

    params.addParameter('Montage', [], @(x) isnumeric(x) || ischar(x) || isstring(x))
    params.addParameter('Finished', false, isLogicalScalar)
    params.addParameter('ConnectTimeout', [], isTimeout)
    params.addParameter('ResponseTimeout', [], isTimeout)
    params.addParameter('DataTimeout', [], isTimeout)
    params.addParameter('Poster', @webupload.zipAndPost, ...
                        @(x) isa(x,'function_handle') && isscalar(x))
    params.addParameter('StageRoot', tempdir, isNonEmptyText)
    params.addParameter('ClearStage', false, isLogicalScalar)


    try
        params.parse(varargin{:});
    catch err
        result = finalise(result,err,[]);
        notify(result)
        return
    end
    opts = params.Results;

    try
        % Recipe, log and config: those given by name, else the ones found from the current folder
        recipePath = opts.recipePath;
        if isempty(recipePath)
            recipePath = getRecipeFileName;
        end
        if isempty(recipePath)
            error('webupload:updateSectionImage:noRecipe', 'No recipe file found.')
        end

        % The log is optional (stageFiles warns, and keeps the previous log for the same sample)
        logPath = opts.logPath;
        if isempty(logPath)
            d = dir('acqLog_*.txt');
            if isscalar(d)
                logPath = fullfile(d.folder,d.name);
            else
                logPath = '';
                if ~isempty(d)
                    warning('webupload:updateSectionImage:manyLogs', ...
                        'Found %d acqLog_*.txt files; no log sent.', numel(d))
                end
            end
        end

        cfg = opts.cfg;
        if isempty(cfg)
            cfgPath = webupload.getConfigFilePath;
            if isempty(cfgPath)
                error('webupload:updateSectionImage:noConfig', ...
                    'No brainsaw_webpreview.json found on the MATLAB path.')
            end
            cfg = webupload.webConfig(cfgPath);
        end

        opts.StageRoot = char(opts.StageRoot);
        opts.Source = char(opts.Source);
        opts.Finished = logical(opts.Finished);
        opts.ClearStage = logical(opts.ClearStage);

        opts.PosterArgs = {};
        for name = {'ConnectTimeout','ResponseTimeout','DataTimeout'}
            if ~isempty(opts.(name{1}))
                opts.PosterArgs = [opts.PosterArgs, name, {opts.(name{1})}];
            end
        end

        result = runPipeline(result,img,recipePath,logPath,cfg,opts);
    catch err
        caught = err;
    end %try

    % report the results
    result = finalise(result,caught,cfg);
    notify(result)
end % updateSectionImage


function result = runPipeline(result,img,recipePath,logPath,cfg,opts)
    % Stage the files, then upload the stage folder, recording what happened in result
    %
    % function result = webupload.updateSectionImage>runPipeline(result,img,recipePath,logPath,cfg,opts)
    %
    % Purpose
    % The part of updateSectionImage that runs inside its try/catch. Refuses a montage
    % for source 'acq'. Reads the microscope ID from the recipe, builds the stage folder
    % path from cfg.siteID, the ID, opts.StageRoot and opts.Source (webupload.stageDirFor
    % checks the IDs, so they are safe as folder names), stages the files with
    % webupload.stageFiles (which empties the folder first if opts.ClearStage is true, but
    % only after checking the images), writes status.json and uploads the folder with
    % opts.Poster, once more after a 429 if opts.Finished.
    %
    % Anything that goes wrong before staging has finished is thrown and caught by
    % updateSectionImage. After that, failures are written to result.error instead, so the
    % stage information survives into the returned result. If staging did not complete,
    % or left no recipe (the server refuses an upload without one), nothing is uploaded.
    %
    % Inputs
    % result     - Result structure of updateSectionImage as it stands before anything
    %              has been done, to be filled in.
    % img        - [], a numeric image or the path of a jpg.
    % recipePath - Path to the recipe file.
    % logPath    - Path to the acquisition log file.
    % cfg        - webupload.webConfig object.
    % opts       - Options structure built in updateSectionImage.
    %
    % Outputs
    % result - The input structure with stage, stageDir, recipeFresh, logFresh and stale
    %          filled in. post and ok are set once the poster has returned. error is set if
    %          staging was incomplete or the poster threw.

    noMontage = isa(opts.Montage,'double') && isequal(size(opts.Montage),[0 0]);
    if ~noMontage && ~strcmp(opts.Source,'analysis')
        error('webupload:updateSectionImage:montageNotAllowed', ...
            'A montage can only be sent with Source ''analysis'', not ''%s''.', opts.Source)
    end

    % Read from the source recipe, never from a copy left in the stage by an earlier call
    micID = webupload.readRecipe(char(recipePath));
    stageDir = webupload.stageDirFor(cfg,micID,opts.StageRoot,opts.Source);

    result.stage = webupload.stageFiles(img,recipePath,logPath,stageDir, ...
                        'Montage',opts.Montage,'ClearStage',opts.ClearStage);
    result.stageDir = stageDir;
    result.recipeFresh = result.stage.recipeStaged;
    result.logFresh = result.stage.logStaged;
    result.stale = ~(result.recipeFresh && result.logFresh);


    if ~result.stage.stageOk || ~result.recipeFresh
        % stageFiles has already warned with the cause; do not upload a partial stage
        result.error = MException('webupload:updateSectionImage:stageFailed', ...
            'staging in "%s" did not complete, nothing uploaded', stageDir);
        return
    end

    try
        webupload.writeStatus(stageDir,opts.Finished);
        result.post = callPoster(opts,stageDir,cfg,micID);
        if opts.Finished && isequal(result.post.httpStatus,429)
            pause(webupload.serverLimits().minUploadIntervalSec + 1)
            result.post = callPoster(opts,stageDir,cfg,micID);
        end
        result.ok = result.post.ok;
    catch err
        result.error = err;
    end %try
end % runPipeline



function post = callPoster(opts,stageDir,cfg,micID)
    % Call the poster and check that its reply has the expected form
    %
    % function post = webupload.updateSectionImage>callPoster(opts,stageDir,cfg,micID)
    %
    % Purpose
    % A poster that throws propagates to the catch in updateSectionImage. Errors with
    % 'webupload:updateSectionImage:badReply' if the reply is not a scalar structure with
    % the fields ok (logical scalar), httpStatus and message (char). The timeouts are
    % appended to the call only when the caller gave them.
    %
    % Inputs
    % opts     - Options structure built in updateSectionImage: the Poster, Source and PosterArgs
    %            fields are used.
    % stageDir - Char path to the folder to upload.
    % cfg      - webupload.webConfig object.
    % micID    - Microscope ID read from the recipe.
    %
    % Outputs
    % post - The poster's reply: structure with fields ok, httpStatus and message.

    post = opts.Poster(stageDir,cfg,micID,opts.Source,opts.PosterArgs{:});
    wellFormed = isstruct(post) && isscalar(post) ...
                 && all(isfield(post,{'ok','httpStatus','message'})) ...
                 && islogical(post.ok) && isscalar(post.ok) ...
                 && ischar(post.message) && (isrow(post.message) || isempty(post.message));
    if ~wellFormed
        error('webupload:updateSectionImage:badReply', ...
            ['poster did not return struct(ok, httpStatus, message) ', ...
             'with logical ok and char message'])
    end
end % callPoster


function result = finalise(result,caught,cfg)
    % Scrub the token from the message and fill result.error for every kind of failure
    %
    % function result = webupload.updateSectionImage>finalise(result,caught,cfg)
    %
    % Purpose
    % The error reported is, in order of preference, the error caught by updateSectionImage,
    % then result.error set by runPipeline, then a 'webupload:updateSectionImage:postFailed'
    % error built from the poster's message. On success only result.post.message is scrubbed.
    % The reported error is rebuilt from the scrubbed text and its message is copied to
    % result.post.message.
    %
    % Inputs
    % result - Result structure as left by runPipeline (or its initial state if runPipeline was not reached).
    % caught - MException caught by updateSectionImage, or [] if there was none.
    % cfg    - webupload.webConfig used to scrub the token from messages, or [] if the
    %          caller did not supply a usable one.
    %
    % Outputs
    % result - The input with a scrubbed post.message, and error set if ok is false.

    if ~isempty(cfg)
        result.post.message = cfg.scrub(result.post.message);
    end
    if ~isempty(caught)
        err = caught;
    elseif ~result.ok && ~isempty(result.error)
        err = result.error;
    elseif ~result.ok
        err = MException('webupload:updateSectionImage:postFailed','%s',result.post.message);
    else
        return
    end

    result.post.message = err.message;
    if ~isempty(cfg)
        result.post.message = cfg.scrub(err.message);
    end
    % An existing MException keeps its original message, so rebuild it from the scrubbed text
    result.error = MException(err.identifier,'%s',result.post.message);
end % finalise


function notify(result)
    % Issue at most one warning describing a failed or stale upload
    %
    % function webupload.updateSectionImage>notify(result)
    %
    % Purpose
    % Warns 'webupload:updateSectionImage:failed' if result.ok is false. If the upload
    % worked but result.stale is true, warns 'webupload:updateSectionImage:stale'. If both
    % apply the failed warning is issued, with the names of the stale files added to its
    % text. stageFiles may already have issued its own warnings. The warning call is
    % guarded because with warning('error',...) in force it throws, and that must not
    % escape.
    %
    % Inputs
    % result - Result structure returned by updateSectionImage.

    text = '';
    id = '';
    if ~result.ok
        id = 'webupload:updateSectionImage:failed';
        text = sprintf('Web preview not updated (%s: %s)', ...
                result.error.identifier, result.error.message);
    end

    if result.stale
        if isempty(id)
            id = 'webupload:updateSectionImage:stale';
            text = 'Web preview uploaded with stale metadata';
        end
        names = {};
        if ~result.recipeFresh
            names{end+1} = 'recipe';
        end
        if ~result.logFresh
            names{end+1} = 'acq log';
        end
        text = sprintf('%s; %s not refreshed for this section', text, strjoin(names,' and '));
        % The recipe is never kept, so only the log has a fallback to describe
        if result.ok
            if result.stage.logKept
                text = [text ' (the previously staged copy was uploaded)'];
            else
                text = [text ' (no log was uploaded)'];
            end
        end
    end

    if isempty(id)
        return
    end

    try
        warning(id,'%s',text)
    catch
        % Deliberately ignored, see above
    end %try
end % notify
