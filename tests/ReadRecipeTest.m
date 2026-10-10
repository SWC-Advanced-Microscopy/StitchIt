classdef ReadRecipeTest < matlab.unittest.TestCase
    % Tests for webupload.readRecipe against the cases in upload_contract.json, shared with
    % the server's tests so both sides read the same IDs from the same recipe.

    properties
        Dir
    end

    methods (TestClassSetup)
        function addPackageToPath(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(fileparts(mfilename('fullpath')), '..')));
        end
    end

    methods (TestMethodSetup)
        function makeDir(tc)
            fx = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Dir = fx.Folder;
        end
    end

    methods (Test)
        function everySharedVectorIsRead(tc)
            vectors = jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')), ...
                'upload_contract.json')));
            for ii = 1:numel(vectors.cases)
                c = vectors.cases(ii);
                [micID, sampleID] = webupload.readRecipe(tc.writeRecipe(c.recipe));
                tc.verifyEqual(micID, c.micID, c.name);
                tc.verifyEqual(sampleID, c.sampleID, c.name);
            end
        end

        function missingFileErrors(tc)
            tc.verifyError(@() webupload.readRecipe(fullfile(tc.Dir, 'nope.yml')), ...
                'webupload:recipeMissing');
        end

        function emptyValueGivesEmpty(tc)
            [micID, sampleID] = webupload.readRecipe(tc.writeRecipe(sprintf('sample: {ID: }\nSYSTEM:\n  ID:   \n')));
            tc.verifyEmpty(micID);
            tc.verifyEmpty(sampleID);
        end
    end

    methods (Access = private)
        function f = writeRecipe(tc, text)
            % UTF-8 bytes, as a recipe file on disk has them (this keeps the BOM case real)
            f = fullfile(tc.Dir, 'recipe.yml');
            fid = fopen(f, 'w');
            fwrite(fid, unicode2native(text, 'UTF-8'));
            fclose(fid);
        end
    end
end
