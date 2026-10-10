classdef ZipFolderTest < matlab.unittest.TestCase
    % Tests for webupload.zipFolder and selectUploadable. Each test builds
    % its own tiny folder.

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
        function keepsOnlyTheAllowedNames(tc)
            keep = webupload.allowedNames();
            drop = {'evil.php', '.htaccess', 'raw.tif', 'noext', 'recipe_old.yml'};
            ZipFolderTest.touch(tc.Dir, [keep, drop]);

            zipPath = webupload.zipFolder(tc.Dir);
            tc.addTeardown(@() delete(zipPath));

            tc.verifyEqual(sort(ZipFolderTest.listZip(zipPath)), sort(keep(:)));
        end

        function zipIsFlatAndIgnoresSubfolders(tc)
            ZipFolderTest.touch(tc.Dir, {'montage.jpg'});
            sub = fullfile(tc.Dir, 'sub');
            mkdir(sub);
            ZipFolderTest.touch(sub, {'recipe.yml'});

            zipPath = webupload.zipFolder(tc.Dir);
            tc.addTeardown(@() delete(zipPath));

            tc.verifyEqual(ZipFolderTest.listZip(zipPath), {'montage.jpg'});
        end

        function zipEndsInDotZipAndExists(tc)
            ZipFolderTest.touch(tc.Dir, {'status.json'});
            zipPath = webupload.zipFolder(tc.Dir);
            tc.addTeardown(@() delete(zipPath));
            tc.verifyTrue(endsWith(zipPath, '.zip'));
            tc.verifyEqual(exist(zipPath, 'file'), 2);
        end

        function emptyDirErrors(tc)
            tc.verifyError(@() webupload.zipFolder(tc.Dir), 'webupload:noFiles');
        end

        function dirWithOnlyUnrecognisedFilesErrors(tc)
            ZipFolderTest.touch(tc.Dir, {'evil.php', 'raw.tif'});
            tc.verifyError(@() webupload.zipFolder(tc.Dir), 'webupload:noFiles');
        end

        function missingDirErrors(tc)
            tc.verifyError(@() webupload.zipFolder(fullfile(tc.Dir, 'nope')), ...
                'webupload:noSuchFolder');
        end
    end

    methods (Static, Access = private)
        function touch(folder, names)
            for ii = 1:numel(names)
                fid = fopen(fullfile(folder, names{ii}), 'w');
                fwrite(fid, 'x');
                fclose(fid);
            end
        end

        function names = listZip(zipPath)
            % Unzip to a scratch folder; return the file names as a column.
            % Any extracted folder means the archive was not flat.
            out = tempname;
            mkdir(out);
            cleaner = onCleanup(@() rmdir(out, 's')); %#ok<NASGU>
            unzip(zipPath, out);
            d = dir(out);
            d = d(~ismember({d.name}, {'.', '..'}));
            assert(~any([d.isdir]), 'zip contained a folder');
            names = {d.name}';
        end
    end
end
