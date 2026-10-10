classdef UpdateSectionImageTest < matlab.unittest.TestCase
    % Tests for webupload.updateSectionImage with an injected fake Poster, so
    % nothing touches the network (except one test against a refused localhost
    % port). All inputs are synthetic temp files.
    % Run: runtests(fullfile(<repo>, 'upload_core', 'tests'))

    properties
        Dir          % scratch root, removed after each test
        StageRoot    % stage root handed to the function (never the real tempdir)
        Cfg          % webupload.webConfig handed to the functions under test
        Recipe
        Log
        Token = 'SECRETTOKEN123'
        Calls        % struct array: folder, cfg, names (files present at call time), micID, source, status
        PosterReply  % what the fake poster returns
        PosterRepliesAfter  % if non-empty, what it returns from the second call on
        PosterError  % if non-empty, the fake poster throws this message
        Out          % result of the function under test, stored by the closure
        WarnMsg      % message of the last warning issued during the call
        WarnId       % its identifier
    end

    properties (Dependent)
        BaseArgs     % name-value cell used by most calls (a property so tc.BaseArgs{:} is legal)
        PathArgs     % the recipe, log and config as named arguments (default Source is overridden by BaseArgs)
    end

    methods (TestClassSetup)
        function addPackageToPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end

    methods (TestMethodSetup)
        function makeFixtures(tc)
            tc.Dir = tempname;
            mkdir(tc.Dir);
            tc.addTeardown(@() rmdir(tc.Dir, 's'));
            tc.StageRoot = fullfile(tc.Dir, 'stageroot');
            tc.Cfg = tc.makeCfg('https://x.example/up.php');
            tc.Recipe = fullfile(tc.Dir, 'recipe_A.yml');
            tc.Log = fullfile(tc.Dir, 'acqLog_A.txt');
            writeText(tc.Recipe, sprintf('sample: {ID: A}\nSYSTEM:\n  ID: mic-1\n'));
            writeText(tc.Log, 'section 1');
            tc.Calls = struct('folder', {}, 'cfg', {}, 'names', {}, 'micID', {}, 'source', {}, 'status', {}, 'extra', {});
            tc.PosterReply = struct('ok', true, 'httpStatus', 200, 'message', 'uploaded');
            tc.PosterRepliesAfter = [];
            tc.PosterError = '';
            tc.Out = [];
            tc.WarnMsg = '';
            tc.WarnId = '';
        end
    end

    methods
        function cfg = makeCfg(tc, url)
            f = fullfile(tc.Dir, 'config.json');
            writeText(f, sprintf( ...
                '{"url":"%s","siteID":"site-1","token":"%s"}', url, tc.Token));
            cfg = webupload.webConfig(f);
        end

        function reply = recordingPoster(tc, folder, cfg, micID, source, varargin)
            % Same signature as webupload.zipAndPost; records what it saw.
            d = dir(folder);
            tc.Calls(end+1) = struct('folder', folder, 'cfg', cfg, ...
                'names', {sort({d(~[d.isdir]).name})}, 'micID', micID, 'source', source, ...
                'status', jsondecode(fileread(fullfile(folder, 'status.json'))), 'extra', {varargin});
            if ~isempty(tc.PosterError)
                error('fake:boom', '%s', tc.PosterError);
            end
            reply = tc.PosterReply;
            if numel(tc.Calls) > 1 && ~isempty(tc.PosterRepliesAfter)
                reply = tc.PosterRepliesAfter;
            end
        end

        function args = get.BaseArgs(tc)
            args = {'Source', 'acq', 'StageRoot', tc.StageRoot, 'Poster', @tc.recordingPoster};
        end

        function args = get.PathArgs(tc)
            args = {'recipePath', tc.Recipe, 'logPath', tc.Log, 'cfg', tc.Cfg};
        end

        function res = update(tc, varargin)
            % Run with the fake poster; store result and the warning issued.
            tc.callCapturing(@() webupload.updateSectionImage( ...
                uint8(magic(8)), tc.PathArgs{:}, tc.BaseArgs{:}, varargin{:}));
            res = tc.Out;
        end

        function callCapturing(tc, fn)
            % Closure capture: the function's output goes to tc.Out and the
            % warning it issued to tc.WarnId/WarnMsg. Warnings are turned on
            % explicitly so lastwarn is set, and the state is restored.
            saved = warning('on', 'all');
            restore = onCleanup(@() warning(saved));
            lastwarn('');
            tc.Out = fn();
            [tc.WarnMsg, tc.WarnId] = lastwarn;
        end

        function cfg = otherCfg(tc)
            % A config for a different site, whose stage folder must be left alone
            f = fullfile(tc.Dir, 'other.json');
            writeText(f, ['{"url":"https://x.example/up.php","siteID":"other",', ...
                '"token":"x"}']);
            cfg = webupload.webConfig(f);
        end

        function cfg = deletedCfg(tc)
            cfg = tc.makeCfg('https://x.example/up.php');
            delete(cfg)
        end

        function turnIntoErrors(tc, id)
            % Make the warning with this id throw for the rest of the test.
            saved = warning('error', id);
            tc.addTeardown(@warning, saved);
        end

        function verifyFailedWarning(tc)
            tc.verifyEqual(tc.WarnId, 'webupload:updateSectionImage:failed');
        end
    end

    methods (Test)
        function happyPathStagesAndPostsOnce(tc)
            res = tc.update();
            tc.verifyTrue(res.ok);
            tc.verifyEmpty(res.error);
            tc.verifyEmpty(tc.WarnId, 'no warning expected on success');
            tc.verifyTrue(res.recipeFresh && res.logFresh);
            tc.verifyFalse(res.stale);
            tc.verifyEqual(res.post.httpStatus, 200);
            tc.verifyNumElements(tc.Calls, 1);
            tc.verifyEqual(tc.Calls.folder, res.stageDir);
            tc.verifyEqual(tc.Calls.names, ...
                {'LastCompleteSection.jpg', 'acqLog.txt', 'recipe.yml', 'status.json', 'tile_thumbnail.jpg'});
            tc.verifyEqual(tc.Calls.cfg.siteID, 'site-1');
            tc.verifyEqual(res.stageDir, fullfile(tc.StageRoot, 'brainsaw_webpreview', 'site-1', 'mic-1', 'acq'));
        end

        function posterGetsTheRecipeMicroscopeIDSourceAcqAndUnfinishedStatus(tc)
            writeText(tc.Recipe, sprintf('SYSTEM:\n  ID: Scope A\n'));
            tc.update();
            tc.verifyEqual(tc.Calls.micID, 'Scope_A');
            tc.verifyEqual(tc.Calls.source, 'acq');
            tc.verifyEqual(tc.Calls.status, struct('finished', false));
        end

        function missingRecipeFileFailsAndNothingIsPosted(tc)
            tc.update();
            tc.Recipe = fullfile(tc.Dir, 'no_such_recipe.yml');
            res = tc.update();
            tc.verifyFalse(res.ok);
            tc.verifyNumElements(tc.Calls, 1, 'nothing may be posted without a readable recipe');
            tc.verifyFailedWarning();
        end

        function recipeWithoutAUsableMicroscopeIDStagesAndPostsNothing(tc)
            for text = {sprintf('sample: {ID: A}\n'), sprintf('SYSTEM:\n  ID: ../x\n'), ...
                        sprintf('SYSTEM:\n  ID: 2photon\n')}
                writeText(tc.Recipe, text{1});
                res = tc.update();
                tc.verifyFalse(res.ok);
                tc.verifyEqual(res.error.identifier, 'webupload:badMicID');
            end
            tc.verifyEmpty(tc.Calls);
            tc.verifyFalse(isfolder(tc.StageRoot), 'nothing may be created under the stage root');
        end

        function sourceRecipeExtensionDoesNotChangeTheStagedName(tc)
            recipeB = fullfile(tc.Dir, 'recipe_B.yaml');
            writeText(recipeB, sprintf('SYSTEM:\n  ID: mic-1\n'));
            tc.Recipe = recipeB;
            tc.update();
            tc.verifyTrue(ismember('recipe.yml', tc.Calls.names));
        end

        % ---- Source and stage folder ----
        function sourceDefaultsToAnalysis(tc)
            tc.callCapturing(@() webupload.updateSectionImage(uint8(magic(8)), tc.PathArgs{:}, ...
                'StageRoot', tc.StageRoot, 'Poster', @tc.recordingPoster));
            tc.verifyEqual(tc.Calls.source, 'analysis');
        end

        function sourceAnalysisIsPassedToThePoster(tc)
            tc.update('Source', 'analysis');
            tc.verifyEqual(tc.Calls.source, 'analysis');
            tc.verifyEqual(tc.Calls.status, struct('finished', false));
        end

        function eachSourceHasItsOwnStageFolder(tc)
            acq = tc.update();
            analysis = tc.update('Source', 'analysis');
            tc.verifyEqual(acq.stageDir, fullfile(tc.StageRoot, 'brainsaw_webpreview', 'site-1', 'mic-1', 'acq'));
            tc.verifyEqual(analysis.stageDir, fullfile(tc.StageRoot, 'brainsaw_webpreview', 'site-1', 'mic-1', 'analysis'));
            tc.verifyTrue(isfile(fullfile(acq.stageDir, 'recipe.yml')), 'the acq stage is left alone');
        end

        function badSourceIsNonFatalAndSendsNothing(tc)
            for bad = {'other', 1, '', {'acq'}}
                tc.callCapturing(@() webupload.updateSectionImage(uint8(magic(8)), tc.PathArgs{:}, tc.BaseArgs{:}, 'Source', bad{1}));
                tc.verifyFalse(tc.Out.ok);
                tc.verifyFailedWarning();
            end
            tc.verifyEmpty(tc.Calls);
        end

        % ---- images and montage ----
        function jpgPathIsStagedAsTheMainImage(tc)
            src = fullfile(tc.Dir, 'section_0007.jpg');
            imwrite(uint8(magic(8)) * 3, src, 'jpg');
            tc.callCapturing(@() webupload.updateSectionImage(src, tc.PathArgs{:}, ...
                tc.BaseArgs{:}, 'Source', 'analysis'));
            tc.verifyTrue(tc.Out.ok);
            tc.verifyEqual(fileread(fullfile(tc.Out.stageDir, 'LastCompleteSection.jpg')), fileread(src));
        end

        function badImageTypesAreNonFatalAndSendNothing(tc)
            bad = {{1}, struct('a', 1), 'no_such_file.jpg', fullfile(tc.Dir, 'x.png'), true, ...
                   zeros(0, 0, 'uint16'), zeros(0, 3)};
            for kk = 1:numel(bad)
                tc.callCapturing(@() webupload.updateSectionImage(bad{kk}, tc.PathArgs{:}, tc.BaseArgs{:}));
                tc.verifyFalse(tc.Out.ok);
                tc.verifyFailedWarning();
            end
            tc.verifyEmpty(tc.Calls);
        end

        function badImageDoesNotWipeTheStageEvenWithClearStage(tc)
            tc.update();
            tc.callCapturing(@() webupload.updateSectionImage(2 * ones(8), tc.PathArgs{:}, ...
                tc.BaseArgs{:}, 'ClearStage', true));
            tc.verifyFalse(tc.Out.ok);
            tc.verifyTrue(isfile(fullfile(tc.Calls(1).folder, 'recipe.yml')));
            tc.verifyNumElements(tc.Calls, 1);
        end

        function startCallStagesNoImageAndDeletesTheStaleOne(tc)
            tc.update();
            first = tc.Calls(1);
            tc.verifyTrue(ismember('LastCompleteSection.jpg', first.names));
            writeText(tc.Recipe, sprintf('sample: {ID: B}\nSYSTEM:\n  ID: mic-1\n'));
            tc.callCapturing(@() webupload.updateSectionImage([], tc.PathArgs{:}, tc.BaseArgs{:}));
            tc.verifyTrue(tc.Out.ok);
            tc.verifyEqual(tc.Calls(2).names, {'acqLog.txt', 'recipe.yml', 'status.json'});
            tc.verifyFalse(isfile(fullfile(tc.Out.stageDir, 'LastCompleteSection.jpg')));
            tc.verifySubstring(fileread(fullfile(tc.Out.stageDir, 'recipe.yml')), 'ID: B');
        end

        function montageWithAcqIsRefusedAndSendsNothing(tc)
            src = fullfile(tc.Dir, 'montage.jpg');
            imwrite(uint8(magic(8)) * 3, src, 'jpg');
            for montage = {uint8(magic(8)), src}
                tc.update('Montage', montage{1});
                tc.verifyFalse(tc.Out.ok);
                tc.verifyFailedWarning();
                tc.verifySubstring(tc.WarnMsg, 'webupload:updateSectionImage:montageNotAllowed');
            end
            tc.verifyEmpty(tc.Calls);
            tc.verifyFalse(isfolder(tc.StageRoot), 'nothing may be staged');
        end

        function onlyALiteralEmptyMontageCountsAsNoMontageForAcq(tc)
            tc.update('Montage', zeros(0, 3));
            tc.verifyFalse(tc.Out.ok);
            tc.verifySubstring(tc.WarnMsg, 'webupload:updateSectionImage:montageNotAllowed');
            tc.verifyEmpty(tc.Calls);
        end

        function montageIsStagedForAnalysis(tc)
            tc.update('Source', 'analysis', 'Montage', uint8(magic(8)));
            tc.verifyTrue(ismember('montage.jpg', tc.Calls.names));
        end

        function montageJpgPathIsStagedForAnalysis(tc)
            src = fullfile(tc.Dir, 'my_montage.jpg');
            imwrite(uint8(magic(8)) * 3, src, 'jpg');
            res = tc.update('Source', 'analysis', 'Montage', src);
            tc.verifyTrue(res.ok);
            tc.verifyEqual(fileread(fullfile(res.stageDir, 'montage.jpg')), fileread(src));
        end

        % ---- Finished, timeouts and the 429 retry ----
        function finishedIsWrittenToStatus(tc)
            tc.update('Finished', true);
            tc.verifyEqual(tc.Calls.status, struct('finished', true));
        end

        function timeoutsAreAppendedToThePosterCallOnlyWhenGiven(tc)
            tc.update();
            tc.verifyEmpty(tc.Calls(1).extra);
            tc.update('ConnectTimeout', 5, 'ResponseTimeout', 10, 'DataTimeout', 11);
            tc.verifyEqual(tc.Calls(2).extra, ...
                {'ConnectTimeout', 5, 'ResponseTimeout', 10, 'DataTimeout', 11});
        end

        function aFinishedCallFollowedByADefaultCallSendsUnfinished(tc)
            tc.update('Finished', true);
            tc.update();
            tc.verifyEqual([tc.Calls.status], [struct('finished', true), struct('finished', false)]);
        end

        function recipeThatCannotBeCopiedIsNotPostedWithoutARecipe(tc)
            % A dangling symlink as the recipe's .part file makes the copy fail while
            % readRecipe on the source succeeds.
            tc.assumeFalse(ispc);
            stageDir = webupload.stageDirFor(tc.Cfg, 'mic-1', tc.StageRoot, 'acq');
            mkdir(stageDir);
            link = fullfile(stageDir, 'recipe.yml.part');
            tc.assumeEqual(system(sprintf('ln -s "%s" "%s"', fullfile(tc.Dir, 'nodir', 'x'), link)), 0);
            res = tc.update();
            tc.verifyFalse(res.ok);
            tc.verifyFalse(res.recipeFresh);
            tc.verifyEmpty(tc.Calls);
            tc.verifyEqual(res.error.identifier, 'webupload:updateSectionImage:stageFailed');
        end

        function badTimeoutIsNonFatal(tc)
            for bad = {0, -1, NaN, Inf, [1 2], 'x'}
                tc.update('ConnectTimeout', bad{1});
                tc.verifyFalse(tc.Out.ok);
            end
            tc.verifyEmpty(tc.Calls);
        end

        function rateLimitedUnfinishedCallIsNotRetried(tc)
            tc.PosterReply = struct('ok', false, 'httpStatus', 429, 'message', 'rate limited');
            res = tc.update();
            tc.verifyFalse(res.ok);
            tc.verifyNumElements(tc.Calls, 1);
        end

        function rateLimitedFinishedCallIsRetriedOnceAfterTheInterval(tc)
            tc.PosterReply = struct('ok', false, 'httpStatus', 429, 'message', 'rate limited');
            tc.PosterRepliesAfter = struct('ok', true, 'httpStatus', 200, 'message', 'uploaded');
            tic
            res = tc.update('Finished', true, 'ConnectTimeout', 5, 'ResponseTimeout', 10, 'DataTimeout', 10);
            waited = toc;
            tc.verifyTrue(res.ok);
            tc.verifyNumElements(tc.Calls, 2);
            tc.verifyEqual(tc.Calls(1).extra, {'ConnectTimeout', 5, 'ResponseTimeout', 10, 'DataTimeout', 10});
            tc.verifyEqual(tc.Calls(2).extra, tc.Calls(1).extra, 'the retry uses the same timeouts');
            tc.verifyEqual(tc.Calls(2).status, struct('finished', true));
            tc.verifyGreaterThanOrEqual(waited, webupload.serverLimits().minUploadIntervalSec + 1);
        end

        function rateLimitedFinishedCallIsRetriedNoMoreThanOnce(tc)
            tc.PosterReply = struct('ok', false, 'httpStatus', 429, 'message', 'rate limited');
            res = tc.update('Finished', true);
            tc.verifyFalse(res.ok);
            tc.verifyEqual(res.post.httpStatus, 429);
            tc.verifyNumElements(tc.Calls, 2);
            tc.verifyFailedWarning();
        end

        function otherFailuresOfAFinishedCallAreNotRetried(tc)
            tc.PosterReply = struct('ok', false, 'httpStatus', 500, 'message', 'broken');
            tc.update('Finished', true);
            tc.verifyNumElements(tc.Calls, 1);
        end

        function errorFieldIsPopulatedOnFailure(tc)
            tc.PosterError = 'kaboom';
            res = tc.update();
            tc.verifyClass(res.error, 'MException');
            tc.verifyEqual(res.error.identifier, 'fake:boom');
            tc.verifySubstring(res.error.message, 'kaboom');
            tc.verifySubstring(tc.WarnMsg, 'fake:boom: kaboom');
        end

        function posterFailureIsNonFatal(tc)
            tc.PosterReply = struct('ok', false, 'httpStatus', 500, 'message', 'server said no');
            res = tc.update();
            tc.verifyFalse(res.ok);
            tc.verifyFailedWarning();
            tc.verifyEqual(res.post.httpStatus, 500);
            tc.verifySubstring(res.post.message, 'server said no');
            tc.verifyNotEmpty(res.error);
        end

        function posterThrowingIsNonFatal(tc)
            tc.PosterError = 'kaboom';
            res = tc.update();
            tc.verifyFalse(res.ok);
            tc.verifyFailedWarning();
            tc.verifySubstring(res.post.message, 'kaboom');
            tc.verifyNotEmpty(res.stage, 'stage info survives a poster failure');
        end

        function malformedPosterReplyIsNonFatal(tc)
            tc.PosterReply = 42;
            res = tc.update();
            tc.verifyFalse(res.ok);
            tc.verifyFailedWarning();
            tc.PosterReply = struct('ok', true, 'httpStatus', 200, 'message', 5);
            res = tc.update();
            tc.verifyFalse(res.ok, 'non-char message is a failure');
            tc.PosterReply = struct('ok', true, 'httpStatus', 200, 'message', ['ab'; 'cd']);
            res = tc.update();
            tc.verifyFalse(res.ok, 'a char matrix message is a failure');
        end

        function nonConfigCfgIsNonFatal(tc)
            for bad = {'cfg.json', struct('url', 'https://x'), [tc.Cfg tc.Cfg], tc.deletedCfg()}
                tc.callCapturing(@() webupload.updateSectionImage( ...
                    uint8(magic(8)), 'recipePath', tc.Recipe, 'logPath', tc.Log, 'cfg', bad{1}, tc.BaseArgs{:}));
                tc.verifyFalse(tc.Out.ok);
                tc.verifyFailedWarning();
                tc.verifySubstring(tc.WarnMsg, '''cfg''');
            end
            tc.verifyEmpty(tc.Calls);
        end

        function logDefaultsToTheOneInTheCurrentFolder(tc)
            old = cd(tc.Dir);
            tc.addTeardown(@() cd(old));
            tc.callCapturing(@() webupload.updateSectionImage(uint8(magic(8)), ...
                'recipePath', tc.Recipe, 'cfg', tc.Cfg, tc.BaseArgs{:}));
            tc.verifyTrue(tc.Out.ok);
            tc.verifyTrue(tc.Out.logFresh);
        end

        function noRecipeInTheCurrentFolderIsNonFatal(tc)
            tc.assumeNotEmpty(which('getRecipeFileName'), 'needs StitchIt''s getRecipeFileName');
            empty = fullfile(tc.Dir, 'empty');
            mkdir(empty);
            old = cd(empty);
            tc.addTeardown(@() cd(old));
            tc.callCapturing(@() webupload.updateSectionImage(uint8(magic(8)), ...
                'cfg', tc.Cfg, tc.BaseArgs{:}));
            tc.verifyFalse(tc.Out.ok);
            tc.verifyFailedWarning();
            tc.verifyEmpty(tc.Calls);
        end
            tc.verifyEmpty(tc.Calls);
        end

        function badImageIsNonFatal(tc)
            tc.callCapturing(@() webupload.updateSectionImage(uint8(1), tc.PathArgs{:}, tc.BaseArgs{:}));
            tc.verifyFalse(tc.Out.ok);
            tc.verifyFailedWarning();
            tc.verifyEmpty(tc.Calls);
        end

        function argumentShapeErrorIsNonFatal(tc)
            tc.callCapturing(@() webupload.updateSectionImage( ...
                uint8(magic(8)), tc.PathArgs{:}, 'Bogus', 1));
            tc.verifyFalse(tc.Out.ok);
            tc.verifyFailedWarning();
        end

        function stageFailureIsNonFatalAndNotPosted(tc)
            % A regular file where the stage root should be: mkdir must fail.
            blocker = fullfile(tc.Dir, 'blocker');
            writeText(blocker, 'x');
            tc.StageRoot = blocker;
            res = tc.update();
            tc.verifyFalse(res.ok);
            tc.verifyFailedWarning();
            tc.verifySubstring(res.post.message, 'did not complete');
            tc.verifyEmpty(tc.Calls);
            tc.verifyEqual(res.error.identifier, 'webupload:updateSectionImage:stageFailed');
        end

        function missingLogIsReportedAsStale(tc)
            tc.update();                                  % a good first section
            tc.Log = fullfile(tc.Dir, 'no_such_log.txt');
            res = tc.update();
            tc.verifyTrue(res.ok);
            tc.verifyTrue(res.recipeFresh);
            tc.verifyFalse(res.logFresh);
            tc.verifyTrue(res.stale);
            tc.verifyEqual(tc.WarnId, 'webupload:updateSectionImage:stale');
            tc.verifySubstring(tc.WarnMsg, 'acq log not refreshed');
            tc.verifySubstring(tc.WarnMsg, 'previously staged copy was uploaded');
            tc.verifyTrue(ismember('acqLog.txt', tc.Calls(2).names), ...
                'previous log is what was uploaded');
        end

        function missingLogForANewSampleIsDroppedAndTheWarningSaysSo(tc)
            tc.update();
            writeText(tc.Recipe, sprintf('sample: {ID: B}\nSYSTEM:\n  ID: mic-1\n'));
            tc.Log = fullfile(tc.Dir, 'no_such_log.txt');
            res = tc.update();
            tc.verifyTrue(res.ok);
            tc.verifyEqual(tc.WarnId, 'webupload:updateSectionImage:stale');
            tc.verifyThat(tc.WarnMsg, ~matlab.unittest.constraints.ContainsSubstring('previously staged'));
            tc.verifySubstring(tc.WarnMsg, 'no log was uploaded');
            tc.verifyFalse(ismember('acqLog.txt', tc.Calls(2).names));
        end

        function staleAndFailureGiveOneFailedWarningNamingTheFile(tc)
            tc.update();
            tc.Log = fullfile(tc.Dir, 'no_such_log.txt');
            tc.PosterError = 'kaboom';
            tc.update();
            tc.verifyFailedWarning();
            tc.verifySubstring(tc.WarnMsg, 'acq log not refreshed');
            tc.verifyThat(tc.WarnMsg, ~matlab.unittest.constraints.ContainsSubstring('was uploaded'));
        end

        function clearStageOptionRemovesPreviousMetadata(tc)
            tc.update();
            tc.Log = fullfile(tc.Dir, 'no_such_log.txt');
            res = tc.update('ClearStage', true);
            tc.verifyTrue(res.ok);
            tc.verifyFalse(ismember('acqLog.txt', tc.Calls(2).names));
            tc.verifyTrue(ismember('recipe.yml', tc.Calls(2).names));
        end

        function repeatedCallsReuseStageWithoutStaleFiles(tc)
            first = tc.update('Source', 'analysis', 'Montage', uint8(magic(8)));
            tc.verifyTrue(ismember('montage.jpg', tc.Calls(1).names));
            second = tc.update('Source', 'analysis');   % no montage this time
            tc.verifyEqual(second.stageDir, first.stageDir);
            tc.verifyEqual(tc.Calls(2).names, ...
                {'LastCompleteSection.jpg', 'acqLog.txt', 'recipe.yml', 'status.json', 'tile_thumbnail.jpg'});
        end

        function tokenNeverAppearsInMessages(tc)
            % Poster throws with the token in its message.
            tc.PosterError = ['failed with ' tc.Token];
            res = tc.update();
            tc.verifyFailedWarning();
            tc.verifyThat(res.post.message, ~matlab.unittest.constraints.ContainsSubstring(tc.Token));
            tc.verifyThat(tc.WarnMsg, ~matlab.unittest.constraints.ContainsSubstring(tc.Token));
            tc.verifyThat(res.error.message, ~matlab.unittest.constraints.ContainsSubstring(tc.Token));
            % Poster replies with a failure message containing the token.
            tc.PosterError = '';
            tc.PosterReply = struct('ok', false, 'httpStatus', 401, 'message', ['bad ' tc.Token]);
            res = tc.update();
            tc.verifyFailedWarning();
            tc.verifyThat(res.post.message, ~matlab.unittest.constraints.ContainsSubstring(tc.Token));
            tc.verifyThat(tc.WarnMsg, ~matlab.unittest.constraints.ContainsSubstring(tc.Token));
        end

        function clearStageOptionOnlyTouchesTheManagedFolder(tc)
            tc.update();                                   % creates the managed folder
            sibling = webupload.stageDirFor(tc.otherCfg(), 'mic-1', tc.StageRoot, 'acq');
            mkdir(sibling);
            writeText(fullfile(sibling, 'keep.txt'), 'x');
            writeText(fullfile(tc.StageRoot, 'keep.txt'), 'x');
            tc.update('ClearStage', true);
            tc.verifyTrue(isfile(fullfile(sibling, 'keep.txt')));
            tc.verifyTrue(isfile(fullfile(tc.StageRoot, 'keep.txt')));
        end

        function stageDirIsCharEvenForStringOptions(tc)
            tc.callCapturing(@() webupload.updateSectionImage( ...
                uint8(magic(8)), tc.PathArgs{:}, ...
                'StageRoot', string(tc.StageRoot), 'Poster', @tc.recordingPoster));
            tc.verifyClass(tc.Out.stageDir, 'char');
            tc.verifyTrue(tc.Out.ok);
        end

        function okMessageIsScrubbedToo(tc)
            tc.PosterReply = struct('ok', true, 'httpStatus', 200, 'message', ['ok ' tc.Token]);
            res = tc.update();
            tc.verifyTrue(res.ok);
            tc.verifyThat(res.post.message, ~matlab.unittest.constraints.ContainsSubstring(tc.Token));
        end

        function errorWithoutIdentifierDoesNotThrow(tc)
            % A plain error('text') has an empty identifier. MATLAB will not build an
            % error with a malformed one, so this is the nearest case that can be tested.
            % error() cannot output a value, so the poster must be a real function.
            poster = @throwWithoutId;
            tc.callCapturing(@() webupload.updateSectionImage( ...
                uint8(magic(8)), tc.PathArgs{:}, ...
                'StageRoot', tc.StageRoot, 'Poster', poster));
            tc.verifyFalse(tc.Out.ok);
            tc.verifySubstring(tc.Out.post.message, 'plain failure');
        end

        % ---- clearStage ----
        function clearStageRemovesOnlyTheManagedFolder(tc)
            tc.update();
            managed = webupload.stageDirFor(tc.Cfg, 'mic-1', tc.StageRoot, 'acq');
            sibling = webupload.stageDirFor(tc.otherCfg(), 'mic-1', tc.StageRoot, 'acq');
            mkdir(sibling);
            writeText(fullfile(sibling, 'keep.txt'), 'x');
            writeText(fullfile(tc.StageRoot, 'keep.txt'), 'x');
            ok = webupload.clearStage(tc.Cfg, 'mic-1', 'StageRoot', tc.StageRoot);
            tc.verifyTrue(ok);
            tc.verifyFalse(isfolder(managed));
            tc.verifyTrue(isfile(fullfile(sibling, 'keep.txt')));
            tc.verifyTrue(isfile(fullfile(tc.StageRoot, 'keep.txt')));
            tc.verifyNumElements(tc.Calls, 1, 'clearStage must not upload');
        end

        function clearStageOnAbsentFolderIsOk(tc)
            tc.verifyTrue(webupload.clearStage(tc.Cfg, 'mic-1', 'StageRoot', tc.StageRoot));
        end

        function clearStageWithNonConfigWarnsAndReturnsFalse(tc)
            for bad = {[], 'cfg.json', struct('siteID', 'site-1'), [tc.Cfg tc.Cfg], tc.deletedCfg()}
                tc.callCapturing(@() webupload.clearStage(bad{1}, 'mic-1', 'StageRoot', tc.StageRoot));
                tc.verifyFalse(tc.Out);
                tc.verifyEqual(tc.WarnId, 'webupload:clearStage:failed');
                tc.verifySubstring(tc.WarnMsg, 'webupload:clearStage:badConfig');
            end
        end

        function clearStageNeverThrowsEvenForBadArguments(tc)
            % warning('error','all') is not allowed in MATLAB, so name the ids.
            tc.turnIntoErrors('webupload:clearStage:failed');
            tc.verifyFalse(webupload.clearStage(tc.Cfg, 'mic-1', 'Bogus', 1));
        end

        function warningsAsErrorsDoNotMakeItThrow(tc)
            tc.turnIntoErrors('webupload:updateSectionImage:failed');
            res = webupload.updateSectionImage(uint8(1), tc.PathArgs{:}, ...
                tc.BaseArgs{:});
            tc.verifyFalse(res.ok);
        end

        function defaultPosterOnUnreachableServerIsNonFatal(tc)
            % Port 9 on localhost refuses the connection; plain http is
            % accepted by webConfig for localhost only.
            tc.Cfg = tc.makeCfg('http://127.0.0.1:9/up.php');
            tc.callCapturing(@() webupload.updateSectionImage( ...
                uint8(magic(8)), tc.PathArgs{:}, 'StageRoot', tc.StageRoot));
            tc.verifyFalse(tc.Out.ok);
            tc.verifyFailedWarning();
            tc.verifyThat(tc.WarnMsg, ~matlab.unittest.constraints.ContainsSubstring(tc.Token));
        end
    end
end


function reply = throwWithoutId(~, ~, ~, ~)
reply = [];
error('plain failure');
end


function writeText(file, txt)
fid = fopen(file, 'w');
assert(fid > 0, 'could not open "%s" for writing', file);
fwrite(fid, txt);
fclose(fid);
end
