classdef ToUint8Test < matlab.unittest.TestCase
    % Tests for webupload.toUint8, which is pure (no files, no JPEG).
    % Run: runtests(fullfile(<repo>, 'upload_core', 'tests'))

    methods (TestClassSetup)
        function addPackageToPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end

    methods (Test)
        function toUint8RoundsFloatHalfUp(tc)
            tc.verifyEqual(webupload.toUint8(0.5 * ones(2)), uint8(128 * ones(2)));
        end

        function toUint8Uint8IsIdentity(tc)
            img = uint8([0 1 127 255; 3 4 5 6]);
            tc.verifyEqual(webupload.toUint8(img), img);
        end

        function toUint8Uint16AutoscalesToMax(tc)
            out = webupload.toUint8(uint16([0 1000; 2000 2000]));
            tc.verifyEqual(out, uint8([0 128; 255 255]));
        end

        function toUint8Uint16AllZeroIsBlack(tc)
            tc.verifyEqual(webupload.toUint8(zeros(3, 3, 'uint16')), zeros(3, 3, 'uint8'));
        end

        function toUint8Int16ClampsNegativesAndAutoscales(tc)
            out = webupload.toUint8(int16([-5 0; 100 200]));
            tc.verifyEqual(out, uint8([0 0; 128 255]));
        end

        function toUint8SingleAccepted(tc)
            tc.verifyEqual(webupload.toUint8(0.5 * ones(2, 'single')), uint8(128 * ones(2)));
        end

        function toUint8FloatOutOfRangeErrors(tc)
            tc.verifyError(@() webupload.toUint8(2 * ones(4)), 'webupload:toUint8:badImage');
        end

        function toUint8NanAndInfError(tc)
            bad = ones(4); bad(3) = NaN;
            tc.verifyError(@() webupload.toUint8(bad), 'webupload:toUint8:badImage');
            bad(3) = Inf;
            tc.verifyError(@() webupload.toUint8(bad), 'webupload:toUint8:badImage');
        end

        function toUint8UnsupportedClassErrors(tc)
            tc.verifyError(@() webupload.toUint8(int32(ones(4))), 'webupload:toUint8:badImage');
        end

        function toUint8BadDimsError(tc)
            tc.verifyError(@() webupload.toUint8(uint8(ones(4,4,3,2))), 'webupload:toUint8:badImage');
            tc.verifyError(@() webupload.toUint8(uint8(ones(4,4,2))), 'webupload:toUint8:badImage');
            tc.verifyError(@() webupload.toUint8(uint8([])), 'webupload:toUint8:badImage');
            tc.verifyError(@() webupload.toUint8(uint8(1:10)), 'webupload:toUint8:badImage');
            tc.verifyError(@() webupload.toUint8(uint8((1:10)')), 'webupload:toUint8:badImage');
        end
    end
end
