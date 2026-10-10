classdef StageFilesTest < matlab.unittest.TestCase
    % Tests for webupload.stageFiles and webupload.stageSpec.
    % Run: runtests(fullfile(<repo>, 'upload_core', 'tests')). All inputs are synthetic
    % temp files; the package folder is put on the path by a fixture so tests run from
    % anywhere.

    properties
        Dir      % scratch root, removed after each test
        Stage
        Recipe
        Log
        Last     % result of the most recent stageOut/stageTo call
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
            tc.Stage = fullfile(tc.Dir, 'stage');
            tc.Recipe = fullfile(tc.Dir, 'recipe_SAMPLE_191209.yml');
            tc.Log = fullfile(tc.Dir, 'acqLog_SAMPLE.txt');
            writeText(tc.Recipe, sprintf('sample:\n  ID: SAMPLE\n'));
            writeText(tc.Log, sprintf('section 1 done\n'));
        end
    end

    methods (Test)
        % ---- stageSpec vs the server ----
        function specNamesAreNamesTheServerKeeps(tc)
            spec = webupload.stageSpec();
            tc.verifyTrue(all(ismember(struct2cell(spec.Names), webupload.allowedNames())));
        end

        % ---- stageFiles: image content ----
        function uint8RgbRoundTrips(tc)
            img = repmat(reshape(uint8([200 100 50]), 1, 1, 3), 16, 16);
            tc.stage(img);
            out = tc.readMain();
            tc.verifySize(out, [16 16 3]);
            tc.verifyEqual(double(squeeze(out(8,8,:)))', [200 100 50], 'AbsTol', 6);
        end

        function uint16GrayIsAutoscaledInJpeg(tc)
            tc.stage(repmat(uint16(2047), 16, 16));
            out = tc.readMain();
            tc.verifyClass(out, 'uint8');
            tc.verifyGreaterThan(double(out(8,8)), 250);
        end

        function uint16RgbWorks(tc)
            img = repmat(reshape(uint16([65535 0 32768]), 1, 1, 3), 16, 16);
            tc.stage(img);
            out = tc.readMain();
            tc.verifySize(out, [16 16 3]);
            tc.verifyGreaterThan(double(out(8,8,1)), 240);
            tc.verifyLessThan(double(out(8,8,2)), 15);
        end

        function doubleZeroToOneIsScaled(tc)
            tc.stage(0.5 * ones(16, 16));
            out = tc.readMain();
            tc.verifyEqual(double(out(8,8)), 128, 'AbsTol', 4);
        end

        function badImageThrowsAndLeavesOldStageIntact(tc)
            tc.stage(uint8(ones(8)));
            before = fileread(fullfile(tc.Stage, 'recipe.yml'));
            tc.verifyError(@() tc.stage(2*ones(8)), 'webupload:toUint8:badImage');
            tc.verifyTrue(isfile(fullfile(tc.Stage, 'LastCompleteSection.jpg')));
            tc.verifyEqual(fileread(fullfile(tc.Stage, 'recipe.yml')), before);
        end

        % ---- stageFiles: images given as a path or as nothing ----
        function jpgPathIsCopiedAsTheMainImage(tc)
            src = tc.makeJpg('section_0042.jpg');
            tc.stage(src);
            tc.verifyEqual(fileread(fullfile(tc.Stage, 'LastCompleteSection.jpg')), fileread(src));
            tc.verifyTrue(tc.Last.mainStaged);
            tc.verifyTrue(isfile(src), 'the source is only read');
        end

        function jpegExtensionAndStringPathAreAccepted(tc)
            src = tc.makeJpg('montage_src.JPEG');
            tc.stage(uint8(ones(8)), 'Montage', string(src));
            tc.verifyEqual(fileread(fullfile(tc.Stage, 'montage.jpg')), fileread(src));
        end

        function badImageTypesThrowBeforeTheStageIsTouched(tc)
            notJpg = fullfile(tc.Dir, 'img.png');
            writeText(notJpg, 'x');
            bad = {{1}, struct('a', 1), @sin, true, 'nope.jpg', fullfile(tc.Dir, 'missing.jpg'), ...
                   notJpg, tc.Dir, ''};
            for kk = 1:numel(bad)
                tc.verifyError(@() tc.stage(bad{kk}), 'webupload:stageFiles:badImage');
                tc.verifyError(@() tc.stage(uint8(ones(8)), 'Montage', bad{kk}), ...
                    'webupload:stageFiles:badImage');
            end
            tc.verifyFalse(isfolder(tc.Stage));
        end

        function onlyALiteralEmptyArrayMeansNoImage(tc)
            for bad = {zeros(0, 0, 'uint16'), zeros(0, 3), ones(0, 'single')}
                tc.verifyError(@() tc.stage(bad{1}), 'webupload:toUint8:badImage');
                tc.verifyError(@() tc.stage(uint8(ones(8)), 'Montage', bad{1}), 'webupload:toUint8:badImage');
            end
            tc.verifyFalse(isfolder(tc.Stage));
        end

        function badImageDoesNotClearTheStage(tc)
            tc.stage(uint8(ones(8)));
            tc.verifyError(@() tc.stage(2*ones(8), 'ClearStage', true), 'webupload:toUint8:badImage');
            tc.verifyTrue(isfile(fullfile(tc.Stage, 'recipe.yml')));
        end

        function clearStageOptionRemovesEverythingElseInTheStage(tc)
            tc.stage(uint8(ones(8)));
            writeText(fullfile(tc.Stage, 'other.txt'), 'x');
            tc.stage(uint8(ones(8)), 'ClearStage', true);
            tc.verifyEqual(tc.stagedNames(), {'LastCompleteSection.jpg', 'acqLog.txt', 'recipe.yml', 'tile_thumbnail.jpg'});
        end

        function emptyImageStagesNoImage(tc)
            r = tc.stageOut([], tc.Recipe, tc.Log);
            tc.verifyFalse(r.mainStaged);
            tc.verifyTrue(r.stageOk);
            tc.verifyEqual(tc.stagedNames(), {'acqLog.txt', 'recipe.yml'});
        end

        function emptyImageDeletesTheStagedOne(tc)
            tc.stage(uint8(ones(8)), 'Montage', uint8(ones(8)));
            tc.stage([]);
            tc.verifyEqual(tc.stagedNames(), {'acqLog.txt', 'recipe.yml'});
        end

        function montageDroppedOnSecondCallIsCleared(tc)
            tc.stage(uint8(ones(8)), 'Montage', uint8(ones(8)));
            tc.stage(uint8(ones(8)));
            tc.verifyFalse(isfile(fullfile(tc.Stage, 'montage.jpg')));
        end

        % ---- stageFiles: card thumbnail ----
        function thumbnailIs500WideAndKeepsTheAspectRatio(tc)
            for sz = {[1000 2003], [1000 1700], [4135 4557]}
                [h, w] = deal(sz{1}(1), sz{1}(2));
                tc.stage(uint8(randi(255, h, w)));
                info = imfinfo(fullfile(tc.Stage, 'tile_thumbnail.jpg'));
                tc.verifyEqual(info.Width, 500);
                tc.verifyEqual(info.Height, round(h * 500 / w), 'AbsTol', 1);
                tc.verifyTrue(tc.Last.thumbnailStaged);
            end
        end

        function thumbnailShowsWhatTheImageShows(tc)
            img = zeros(400, 2000, 3, 'uint8');
            img(:, 1001:end, :) = 255;   % left half black, right half white
            img(:, :, 2) = 0;            % no green: magenta on the right
            tc.stage(img);
            t = imread(fullfile(tc.Stage, 'tile_thumbnail.jpg'));
            tc.verifySize(t, [100 500 3]);
            tc.verifyLessThan(double(t(50, 100, 1)), 20);
            tc.verifyGreaterThan(double(t(50, 400, 1)), 235);
            tc.verifyLessThan(double(t(50, 400, 2)), 40);
        end

        function narrowImageIsNotEnlarged(tc)
            tc.stage(uint8(ones(100, 300)));
            info = imfinfo(fullfile(tc.Stage, 'tile_thumbnail.jpg'));
            tc.verifyEqual([info.Width info.Height], [300 100]);
        end

        function wideOneRowImageStillGivesAThumbnail(tc)
            tc.stage(uint8(randi(255, 2, 3000)));
            info = imfinfo(fullfile(tc.Stage, 'tile_thumbnail.jpg'));
            tc.verifyEqual([info.Width info.Height], [500 1]);
        end

        function thumbnailIsMadeFromAJpgPath(tc)
            src = fullfile(tc.Dir, 'big.jpg');
            imwrite(uint8(randi(255, 1200, 1500)), src, 'jpg');
            tc.stage(src);
            info = imfinfo(fullfile(tc.Stage, 'tile_thumbnail.jpg'));
            tc.verifyEqual([info.Width info.Height], [500 400]);
        end

        function noImageMeansNoThumbnail(tc)
            tc.stage(uint8(ones(10, 1000)));
            tc.verifyTrue(isfile(fullfile(tc.Stage, 'tile_thumbnail.jpg')));
            tc.stage([]);
            tc.verifyFalse(tc.Last.thumbnailStaged);
            tc.verifyFalse(isfile(fullfile(tc.Stage, 'tile_thumbnail.jpg')));
        end

        function montageThumbnailIs500WideAndGoneWithTheMontage(tc)
            tc.stageOut(uint8(ones(8)), tc.Recipe, tc.Log, 'Montage', uint8(randi(255, 1000, 2000)));
            info = imfinfo(fullfile(tc.Stage, 'montage_thumbnail.jpg'));
            tc.verifyEqual([info.Width info.Height], [500 250]);
            tc.stageOut(uint8(ones(8)), tc.Recipe, tc.Log);
            tc.verifyFalse(isfile(fullfile(tc.Stage, 'montage.jpg')));
            tc.verifyFalse(isfile(fullfile(tc.Stage, 'montage_thumbnail.jpg')));
        end

        function unreadableJpgWarnsAndDropsTheOldThumbnail(tc)
            tc.stage(uint8(ones(10, 1000)));
            bad = fullfile(tc.Dir, 'bad.jpg');
            writeText(bad, 'not a jpeg');
            tc.verifyWarning(@() tc.stage(bad), 'webupload:stageFiles:thumbnailFailed');
            tc.verifyTrue(tc.Last.mainStaged, 'the image itself is still staged');
            tc.verifyTrue(tc.Last.stageOk, 'a missing thumbnail is not a stage failure');
            tc.verifyFalse(tc.Last.thumbnailStaged);
            tc.verifyFalse(isfile(fullfile(tc.Stage, 'tile_thumbnail.jpg')), ...
                'an old thumbnail must never go up beside a new image');
        end

        % ---- stageFiles: file naming ----
        function filesHaveTheNamesTheServerKeeps(tc)
            r = tc.stageOut(uint8(ones(8)), tc.Recipe, tc.Log, 'Montage', uint8(ones(8)));
            tc.verifyEqual(tc.stagedNames(), ...
                {'LastCompleteSection.jpg', 'acqLog.txt', 'montage.jpg', 'montage_thumbnail.jpg', 'recipe.yml', 'tile_thumbnail.jpg'});
            tc.verifyTrue(r.mainStaged && r.thumbnailStaged && r.montageStaged && r.montageThumbnailStaged && r.recipeStaged && r.logStaged && r.stageOk);
            tc.verifyNumElements(r.files, 6);
            tc.verifyTrue(all(cellfun(@isfile, r.files)));
        end

        function yamlRecipeIsStagedAsRecipeYml(tc)
            r = fullfile(tc.Dir, 'my_recipe.yaml');
            writeText(r, 'x');
            tc.stage(uint8(ones(8)), r);
            tc.verifyEqual(tc.stagedNames(), {'LastCompleteSection.jpg', 'acqLog.txt', 'recipe.yml', 'tile_thumbnail.jpg'});
        end

        function otherFilesInTheStageAreLeftAlone(tc)
            mkdir(tc.Stage);
            hidden = fullfile(tc.Stage, '._recipe.yml');
            other = fullfile(tc.Stage, 'recipe_OLD.yml');
            writeText(hidden, 'appledouble');
            writeText(other, 'other');
            tc.stage(uint8(ones(8)));
            tc.verifyEqual(fileread(hidden), 'appledouble');
            tc.verifyEqual(fileread(other), 'other');
        end

        % ---- recipe / log handling ----
        function missingLogWarnsButStagesImage(tc)
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), tc.Recipe, ...
                fullfile(tc.Dir, 'nope.txt')), 'webupload:stageFiles:missingLog');
            r = tc.Last;
            tc.verifyTrue(isfile(fullfile(tc.Stage, 'LastCompleteSection.jpg')));
            tc.verifyFalse(isfile(fullfile(tc.Stage, 'acqLog.txt')));
            tc.verifyTrue(r.recipeStaged);
            tc.verifyFalse(r.logStaged);
        end

        function missingLogKeepsPreviousLog(tc)
            tc.stage(uint8(ones(8)));
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), tc.Recipe, ...
                fullfile(tc.Dir, 'typo.txt')), 'webupload:stageFiles:missingLog');
            tc.verifyEqual(fileread(fullfile(tc.Stage, 'acqLog.txt')), sprintf('section 1 done\n'));
        end

        function missingLogFallsBackOnlyForTheSameSample(tc)
            tc.stage(uint8(ones(8)));
            other = fullfile(tc.Dir, 'recipe_OTHER.yml');
            writeText(other, sprintf('sample:\n  ID: OTHER\n'));
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), other, fullfile(tc.Dir, 'nope.txt')), ...
                'webupload:stageFiles:missingLog');
            tc.verifyFalse(isfile(fullfile(tc.Stage, 'acqLog.txt')), 'another sample must not get the old log');
            tc.verifyFalse(tc.Last.logKept);
        end

        function theMissingLogWarningSaysWhatHappensToThePreviousLog(tc)
            tc.stage(uint8(ones(8)));
            same = tc.warningText(@() tc.stageOut(uint8(ones(8)), tc.Recipe, fullfile(tc.Dir, 'nope.txt')));
            tc.verifySubstring(same, 'previous log is kept');
            other = fullfile(tc.Dir, 'recipe_OTHER.yml');
            writeText(other, sprintf('sample:\n  ID: OTHER\n'));
            changed = tc.warningText(@() tc.stageOut(uint8(ones(8)), other, fullfile(tc.Dir, 'nope.txt')));
            tc.verifySubstring(changed, 'previous log is removed');
        end

        function unreadableNewRecipeWarnsInsteadOfThrowing(tc)
            tc.assumeFalse(ispc);
            tc.stage(uint8(ones(8)));
            fresh = fullfile(tc.Dir, 'recipe_fresh.yml');
            writeText(fresh, sprintf('sample:\n  ID: SAMPLE\n'));
            tc.assumeEqual(system(sprintf('chmod 000 "%s"', fresh)), 0);
            tc.addTeardown(@() system(sprintf('chmod 644 "%s"', fresh)));
            fid = fopen(fresh, 'r');
            if fid > 0, fclose(fid); end
            tc.assumeTrue(fid < 0, 'cannot make the recipe unreadable (running as root?)');
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), fresh, tc.Log), ...
                'webupload:stageFiles:copyFailed');
            tc.verifyFalse(tc.Last.recipeStaged);
            tc.verifyFalse(isfile(fullfile(tc.Stage, 'recipe.yml')));
        end

        function failedClearStageWarnsAndReportsFailure(tc)
            tc.assumeFalse(ispc);
            tc.stage(uint8(ones(8)));
            % A read-only parent stops the stage folder itself being removed
            tc.assumeEqual(system(sprintf('chmod 555 "%s"', tc.Dir)), 0);
            tc.addTeardown(@() system(sprintf('chmod 755 "%s"', tc.Dir)));
            probe = fopen(fullfile(tc.Dir, 'probe.tmp'), 'w');
            if probe > 0, fclose(probe); delete(fullfile(tc.Dir, 'probe.tmp')); end
            tc.assumeTrue(probe < 0, 'cannot make the parent read-only (running as root?)');
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), tc.Recipe, tc.Log, 'ClearStage', true), ...
                'webupload:stageFiles:stageFailed');
            tc.verifyFalse(tc.Last.stageOk);
        end

        function missingLogIsKeptForTheSameSampleAndReported(tc)
            tc.stage(uint8(ones(8)));
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), tc.Recipe, fullfile(tc.Dir, 'nope.txt')), ...
                'webupload:stageFiles:missingLog');
            tc.verifyTrue(tc.Last.logKept);
        end

        function missingLogIsDroppedWhenTheSampleCannotBeCompared(tc)
            noSample = fullfile(tc.Dir, 'recipe_none.yml');
            writeText(noSample, sprintf('SYSTEM:\n  ID: m\n'));
            tc.stage(uint8(ones(8)), noSample);
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), noSample, fullfile(tc.Dir, 'nope.txt')), ...
                'webupload:stageFiles:missingLog');
            tc.verifyFalse(isfile(fullfile(tc.Stage, 'acqLog.txt')));
        end

        function missingRecipeWarnsButStagesImage(tc)
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), ...
                fullfile(tc.Dir, 'nope.yml'), tc.Log), 'webupload:stageFiles:missingRecipe');
            r = tc.Last;
            tc.verifyTrue(isfile(fullfile(tc.Stage, 'LastCompleteSection.jpg')));
            tc.verifyFalse(r.recipeStaged);
            tc.verifyTrue(r.logStaged);
            tc.verifyTrue(r.stageOk);
        end

        function missingRecipeNeverFallsBackToThePreviousOne(tc)
            tc.stage(uint8(ones(8)));
            tc.verifyTrue(isfile(fullfile(tc.Stage, 'recipe.yml')));
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), ...
                fullfile(tc.Dir, 'typo.yml'), tc.Log), 'webupload:stageFiles:missingRecipe');
            tc.verifyFalse(isfile(fullfile(tc.Stage, 'recipe.yml')));
            tc.verifyFalse(tc.Last.recipeStaged);
            tc.verifyEmpty(tc.Last.recipeSource);
        end

        function nonTextSourcesWarnInsteadOfThrowing(tc)
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), [], tc.Log), ...
                'webupload:stageFiles:missingRecipe');
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), tc.Recipe, 42), ...
                'webupload:stageFiles:missingLog');
            tc.verifyTrue(isfile(fullfile(tc.Stage, 'LastCompleteSection.jpg')));
        end

        function folderAsRecipeOrLogWarns(tc)
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), tc.Dir, tc.Log), ...
                'webupload:stageFiles:missingRecipe');
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), tc.Recipe, tc.Dir), ...
                'webupload:stageFiles:missingLog');
        end

        function sourceInsideStageUnderTheStagedNameIsPreserved(tc)
            mkdir(tc.Stage);
            inStage = fullfile(tc.Stage, 'recipe.yml');
            writeText(inStage, 'live recipe');
            tc.stage(uint8(ones(8)), inStage);
            tc.verifyEqual(fileread(inStage), 'live recipe');
        end

        function sourceInsideStageUnderAnotherNameIsNeverDeleted(tc)
            mkdir(tc.Stage);
            inStage = fullfile(tc.Stage, 'recipe_live.yml');
            writeText(inStage, 'live recipe');
            tc.stage(uint8(ones(8)), inStage);
            tc.verifyEqual(fileread(inStage), 'live recipe');
            tc.verifyEqual(fileread(fullfile(tc.Stage, 'recipe.yml')), 'live recipe');
        end

        function sourcesAreUnmodified(tc)
            before = {fileread(tc.Recipe), fileread(tc.Log)};
            infoBefore = {dir(tc.Recipe), dir(tc.Log)};
            tc.stage(uint8(ones(8)));
            tc.verifyEqual({fileread(tc.Recipe), fileread(tc.Log)}, before);
            tc.verifyEqual(dir(tc.Recipe).datenum, infoBefore{1}.datenum);
            tc.verifyEqual(dir(tc.Log).datenum, infoBefore{2}.datenum);
        end

        % ---- file-system failures ----
        function unwritableStageDirWarnsAndReportsFailure(tc)
            underAFile = fullfile(tc.Recipe, 'sub');   % mkdir below a regular file fails
            tc.verifyWarning(@() tc.stageTo(underAFile, uint8(ones(8))), ...
                'webupload:stageFiles:stageFailed');
            tc.verifyFalse(tc.Last.stageOk);
        end

        function copyFailureWarnsAndStillStagesImageAndRecipe(tc)
            tc.assumeFalse(ispc);
            % fileattrib cannot clear the read bit on Unix, so use chmod
            tc.assumeEqual(system(sprintf('chmod 000 "%s"', tc.Log)), 0);
            tc.addTeardown(@() system(sprintf('chmod 644 "%s"', tc.Log)));
            fid = fopen(tc.Log, 'r');
            if fid > 0, fclose(fid); end
            tc.assumeTrue(fid < 0, 'cannot make the log unreadable (running as root?)');
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), tc.Recipe, tc.Log), ...
                'webupload:stageFiles:copyFailed');
            tc.verifyTrue(tc.Last.recipeStaged);
            tc.verifyFalse(tc.Last.logStaged);
            tc.verifyTrue(isfile(fullfile(tc.Stage, 'LastCompleteSection.jpg')));
        end

        function readOnlyStageFailsCleanlyWithoutPartFiles(tc)
            tc.assumeFalse(ispc);
            tc.stage(uint8(ones(8)));
            fileattrib(tc.Stage, '-w', 'a');
            tc.addTeardown(@() fileattrib(tc.Stage, '+w', 'u'));
            probe = fopen(fullfile(tc.Stage, 'probe.tmp'), 'w');
            if probe > 0, fclose(probe); delete(fullfile(tc.Stage, 'probe.tmp')); end
            tc.assumeTrue(probe < 0, 'cannot make the stage read-only (running as root?)');
            tc.verifyWarning(@() tc.stageOut(uint8(ones(8)), tc.Recipe, tc.Log), ...
                'webupload:stageFiles:stageFailed');
            tc.verifyFalse(tc.Last.stageOk);
            tc.verifyEmpty(dir(fullfile(tc.Stage, '*.part')));
        end

        function undeletableStaleImageSetsStageFailed(tc)
            tc.stage(uint8(ones(8)));
            stale = fullfile(tc.Stage, 'LastCompleteSection.jpg');
            fileattrib(stale, '-w');
            tc.addTeardown(@() isfile(stale) && fileattrib(stale, '+w'));
            s = warning('off', 'all');
            delete(stale);
            warning(s);
            tc.assumeTrue(isfile(stale), 'this platform lets a read-only file be deleted');
            tc.verifyWarning(@() tc.stageOut([], tc.Recipe, tc.Log), ...
                'webupload:stageFiles:stageFailed');
            tc.verifyFalse(tc.Last.stageOk);
            tc.verifyTrue(tc.Last.recipeStaged);   % the new recipe is in place
        end

        function unrelatedPartFilesSurviveAndOwnAreRemoved(tc)
            mkdir(tc.Stage);
            other = fullfile(tc.Stage, 'other_tool.part');
            writeText(other, 'keep me');
            tc.stage(uint8(ones(8)));
            tc.verifyEqual(fileread(other), 'keep me');
            tc.verifyEqual(numel(dir(fullfile(tc.Stage, '*.part'))), 1);
        end
    end

    methods
        function stage(tc, img, varargin)
            % Stage with the fixture recipe/log unless a recipe path is given first.
            recipe = tc.Recipe;
            if ~isempty(varargin) && ischar(varargin{1}) && ~any(strcmp(varargin{1}, {'Montage', 'ClearStage'}))
                recipe = varargin{1};
                varargin(1) = [];
            end
            tc.Last = webupload.stageFiles(img, recipe, tc.Log, tc.Stage, varargin{:});
        end

        function r = stageOut(tc, img, recipe, log, varargin)
            r = webupload.stageFiles(img, recipe, log, tc.Stage, varargin{:});
            tc.Last = r;
        end

        function stageTo(tc, stageDir, img)
            tc.Last = webupload.stageFiles(img, tc.Recipe, tc.Log, stageDir);
        end

        function msg = warningText(tc, fn)
            % Text of the last warning issued while fn runs.
            saved = warning('on', 'all');
            restore = onCleanup(@() warning(saved));
            lastwarn('');
            fn();
            msg = lastwarn;
            tc.verifyNotEmpty(msg);
        end

        function out = readMain(tc)
            out = imread(fullfile(tc.Stage, 'LastCompleteSection.jpg'));
        end

        function names = stagedNames(tc)
            d = dir(tc.Stage);
            names = {d(~[d.isdir]).name};
        end

        function p = makeJpg(tc, name)
            p = fullfile(tc.Dir, name);
            imwrite(uint8(magic(8)) * 3, p, 'jpg');
        end
    end
end


function writeText(path, txt)
fid = fopen(path, 'w');
assert(fid > 0, 'Could not open "%s" for writing.', path);
closer = onCleanup(@() fclose(fid));
fwrite(fid, txt);
end
