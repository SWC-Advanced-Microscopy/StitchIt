classdef SelectUploadableTest < matlab.unittest.TestCase
    % Tests for webupload.allowedNames and webupload.selectUploadable. Each test builds
    % its own folder of empty files.

    properties
        Dir
    end

    methods (TestMethodSetup)
        function makeDir(tc)
            fixture = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Dir = fixture.Folder;
        end
    end

    methods (Test)
        function keepsExactlyTheAllowedNames(tc)
            SelectUploadableTest.touch(tc.Dir, [webupload.allowedNames(), {'evil.php'}]);
            tc.verifyEqual(sort(webupload.selectUploadable(tc.Dir)), sort(webupload.allowedNames()));
        end

        function skipsNearMisses(tc)
            % Same extensions as allowed files, different names (or case).
            SelectUploadableTest.touch(tc.Dir, {'recipe_2020.yml', 'Montage.jpg', 'montage.JPG', ...
                'LastCompleteSection_01.jpg', 'acqLog_x.txt', 'status.json.bak', '.status.json'});
            tc.verifyEmpty(webupload.selectUploadable(tc.Dir));
        end

        function skipsAFolderWithAnAllowedName(tc)
            mkdir(fullfile(tc.Dir, 'recipe.yml'));
            SelectUploadableTest.touch(tc.Dir, {'status.json'});
            tc.verifyEqual(webupload.selectUploadable(tc.Dir), {'status.json'});
        end
    end

    methods (Static, Access = private)
        function touch(dirPath, names)
            for i = 1:numel(names)
                fclose(fopen(fullfile(dirPath, names{i}), 'w'));
            end
        end
    end
end % SelectUploadableTest
