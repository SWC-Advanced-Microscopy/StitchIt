classdef WriteStatusTest < matlab.unittest.TestCase
    % Tests for webupload.writeStatus.

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
        function writesFinishedFlag(tc)
            for flag = [true false]
                webupload.writeStatus(tc.Dir, flag);
                raw = fileread(fullfile(tc.Dir, 'status.json'));
                tc.verifyEqual(jsondecode(raw), struct('finished', flag));
            end
        end

        function overwritesThePreviousFile(tc)
            webupload.writeStatus(tc.Dir, false);
            webupload.writeStatus(tc.Dir, true);
            tc.verifyTrue(jsondecode(fileread(fullfile(tc.Dir, 'status.json'))).finished);
        end

        function rejectsNonLogicalInput(tc)
            tc.verifyError(@() webupload.writeStatus(tc.Dir, 'yes'), 'webupload:badStatus');
            tc.verifyError(@() webupload.writeStatus(tc.Dir, [true true]), 'webupload:badStatus');
            tc.verifyError(@() webupload.writeStatus(tc.Dir, 1), 'webupload:badStatus');
        end

        function missingFolderErrors(tc)
            tc.verifyError(@() webupload.writeStatus(fullfile(tc.Dir, 'nope'), true), ...
                'webupload:statusFailed');
        end
    end
end
