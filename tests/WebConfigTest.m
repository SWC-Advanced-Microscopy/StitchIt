classdef WebConfigTest < matlab.unittest.TestCase
    % Tests for webupload.webConfig (loading, validation and token protection) and the
    % file-name whitelist.

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
        % ---- loading and validation ----
        function validFileReturnsFields(tc)
            cfg = webupload.webConfig(tc.writeJson(WebConfigTest.good()));
            tc.verifyEqual(cfg.url, 'https://example.org/upload.php');
            tc.verifyEqual(cfg.siteID, 'site_a-1');
            tc.verifyFalse(isprop(cfg, 'micID'));
        end

        function valuesAreTrimmed(tc)
            s = WebConfigTest.good();
            s.token = sprintf('  tok123\n');
            s.siteID = sprintf(' site_a-1 ');
            cfg = webupload.webConfig(tc.writeJson(s));
            tc.verifyEqual(cfg.siteID, 'site_a-1');
            tc.verifyEqual(cfg.scrub('a tok123 b'), 'a *** b');
        end

        function missingFileErrors(tc)
            tc.verifyError(@() webupload.webConfig(fullfile(tc.Dir, 'absent.json')), ...
                'webupload:configMissing');
        end

        function missingFieldErrorsAndNamesField(tc)
            for field = {'token', 'siteID', 'url'}
                f = tc.writeJson(rmfield(WebConfigTest.good(), field{1}));
                try
                    webupload.webConfig(f);
                    tc.verifyFail('expected the constructor to error');
                catch err
                    tc.verifyEqual(err.identifier, 'webupload:configIncomplete');
                    tc.verifySubstring(err.message, field{1});
                end
            end
        end

        function emptyOrBlankFieldErrors(tc)
            for blank = {'', '   '}
                s = WebConfigTest.good(); s.token = blank{1};
                tc.verifyError(@() webupload.webConfig(tc.writeJson(s)), 'webupload:configIncomplete');
            end
        end

        function nonTextFieldErrorsWithWrongType(tc)
            for field = {'siteID', 'token', 'url'}
                for bad = {42, ['ab'; 'cd']}
                    s = WebConfigTest.good(); s.(field{1}) = bad{1};
                    tc.verifyError(@() webupload.webConfig(tc.writeJson(s)), 'webupload:configWrongType');
                end
            end
        end

        function malformedJsonErrors(tc)
            f = tc.writeJson('{not json');
            tc.verifyError(@() webupload.webConfig(f), 'webupload:configInvalid');
        end

        function jsonArrayRootErrors(tc)
            f = tc.writeJson([WebConfigTest.good(), WebConfigTest.good()]);
            tc.verifyError(@() webupload.webConfig(f), 'webupload:configInvalid');
        end

        function badIDsError(tc)
            for bad = {'has space', 'a/b', '../x', 'a.b', '2photon', '_x', '-x'}
                s = WebConfigTest.good(); s.siteID = bad{1};
                tc.verifyError(@() webupload.webConfig(tc.writeJson(s)), 'webupload:configInvalid');
            end
        end

        function timeoutsDefaultAndOverride(tc)
            cfg = webupload.webConfig(tc.writeJson(WebConfigTest.good()));
            tc.verifyEqual([cfg.connectTimeout cfg.responseTimeout cfg.dataTimeout], [15 60 60]);
            s = WebConfigTest.good(); s.responseTimeout = 300;
            cfg = webupload.webConfig(tc.writeJson(s));
            tc.verifyEqual([cfg.connectTimeout cfg.responseTimeout cfg.dataTimeout], [15 300 60]);
        end

        function badTimeoutsError(tc)
            for bad = {-1, 0, 'soon', Inf, [1 2]}
                s = WebConfigTest.good(); s.dataTimeout = bad{1};
                tc.verifyError(@() webupload.webConfig(tc.writeJson(s)), 'webupload:configWrongType');
            end
        end

        function httpUrlIsRejected(tc)
            s = WebConfigTest.good(); s.url = 'http://example.org/upload.php';
            tc.verifyError(@() webupload.webConfig(tc.writeJson(s)), 'webupload:insecureUrl');
        end

        function localhostHttpIsAllowed(tc)
            for u = {'http://localhost/u.php', 'http://localhost:8080/u.php', 'http://127.0.0.1:8000/upload.php'}
                s = WebConfigTest.good(); s.url = u{1};
                cfg = webupload.webConfig(tc.writeJson(s));
                tc.verifyEqual(cfg.url, u{1});
            end
        end

        function lookalikeLocalhostHostIsRejected(tc)
            for u = {'http://localhost.evil.com/u', 'http://127.0.0.1.evil.com/u'}
                s = WebConfigTest.good(); s.url = u{1};
                tc.verifyError(@() webupload.webConfig(tc.writeJson(s)), 'webupload:insecureUrl');
            end
        end

        function micIDInTheFileIsRefused(tc)
            % The microscope ID is read from the recipe, so a config that has one is an error.
            s = WebConfigTest.good(); s.micID = 'mic_1';
            try
                webupload.webConfig(tc.writeJson(s));
                tc.verifyFail('expected the constructor to error');
            catch err
                tc.verifyEqual(err.identifier, 'webupload:configMicID');
                tc.verifySubstring(err.message, 'recipe');
            end
        end

        function pathIsRequired(tc)
            tc.verifyError(@() webupload.webConfig(), 'MATLAB:narginchk:notEnoughInputs');
        end

        function propertiesCannotBeChangedAfterConstruction(tc)
            cfg = webupload.webConfig(tc.writeJson(WebConfigTest.good()));
            tc.verifyError(@() WebConfigTest.setUrl(cfg, 'http://evil.example/'), ...
                'MATLAB:class:SetProhibited');
            tc.verifyEqual(cfg.url, 'https://example.org/upload.php');
        end

        % ---- token protection ----
        function tokenCannotBeRead(tc)
            cfg = webupload.webConfig(tc.writeJson(WebConfigTest.good()));
            tc.verifyError(@() cfg.token, 'MATLAB:class:GetProhibited');
        end

        function tokenDoesNotAppearInDisplay(tc)
            cfg = webupload.webConfig(tc.writeJson(WebConfigTest.good()));
            txt = evalc('disp(cfg)');
            tc.verifyThat(txt, ~matlab.unittest.constraints.ContainsSubstring('tok123'));
            txt = evalc('cfg');
            tc.verifyThat(txt, ~matlab.unittest.constraints.ContainsSubstring('tok123'));
        end

        function authHeaderCarriesTheToken(tc)
            cfg = webupload.webConfig(tc.writeJson(WebConfigTest.good()));
            h = cfg.authHeader();
            tc.verifyClass(h, 'matlab.net.http.HeaderField');
            tc.verifyEqual(char(h.Name), 'Authorization');
            tc.verifyEqual(char(h.Value), 'Bearer tok123');
        end

        function scrubRemovesEveryOccurrence(tc)
            cfg = webupload.webConfig(tc.writeJson(WebConfigTest.good()));
            msg = cfg.scrub('bad Bearer tok123 and again tok123 end');
            tc.verifyEmpty(strfind(msg, 'tok123'));
            tc.verifyEqual(msg, 'bad Bearer *** and again *** end');
        end

        function scrubNeverThrows(tc)
            cfg = webupload.webConfig(tc.writeJson(WebConfigTest.good()));
            tc.verifyEqual(cfg.scrub('msg'), 'msg');
            tc.verifyEqual(cfg.scrub(''), '');
            tc.verifyEqual(cfg.scrub(5), '');
            tc.verifyEqual(cfg.scrub(['ab'; 'cd']), '');
        end

        function constructorErrorsAreScrubbed(tc)
            % The url error echoes the url, and here the url holds the token.
            s = WebConfigTest.good(); s.url = ['http://evil.example/' s.token];
            f = tc.writeJson(s);
            try
                webupload.webConfig(f);
                tc.verifyFail('expected the constructor to error');
            catch err
                tc.verifyEqual(err.identifier, 'webupload:insecureUrl');
                tc.verifyThat(err.message, ~matlab.unittest.constraints.ContainsSubstring(s.token));
                tc.verifySubstring(err.message, 'http://evil.example/***');
            end
        end

        function constructorErrorsAreScrubbedWhenTokenHasEscapedQuotes(tc)
            % The JSON token abc"def is written abc\"def in the file.
            f = tc.writeJson('{"url":"http://evil/abc\"def","siteID":"site-1","token":"abc\"def"}');
            try
                webupload.webConfig(f);
                tc.verifyFail('expected the constructor to error');
            catch err
                tc.verifyThat(err.message, ~matlab.unittest.constraints.ContainsSubstring('abc"def'));
                tc.verifySubstring(err.message, 'http://evil/***');
            end
        end

        function constructorErrorsAreScrubbedEvenIfTheJsonIsBroken(tc)
            % The token is found with a regexp on the raw text, so it is still removed
            % from the error message if the file cannot be parsed.
            f = tc.writeJson('{"url":"https://x.example/tok123", "token":"tok123" "oops"}');
            try
                webupload.webConfig(f);
                tc.verifyFail('expected the constructor to error');
            catch err
                tc.verifyEqual(err.identifier, 'webupload:configInvalid');
                tc.verifyThat(err.message, ~matlab.unittest.constraints.ContainsSubstring('tok123'));
            end
        end

        % ---- not config: the shared contract (upload_contract.json, a copy of tests/web/) ----
        function minUploadIntervalMatchesContract(tc)
            c = jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')), 'upload_contract.json')));
            tc.verifyEqual(webupload.serverLimits().minUploadIntervalSec, c.minUploadIntervalSec);
        end

        function maxZipMatchesContract(tc)
            c = jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')), 'upload_contract.json')));
            tc.verifyEqual(webupload.serverLimits().maxZipBytes, c.maxZipBytes);
        end

        function nameWhitelistMatchesContract(tc)
            c = jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')), 'upload_contract.json')));
            tc.verifyEqual(sort(webupload.allowedNames()), sort(c.allowedNames(:)'));
        end
    end

    methods (Static, Access = private)
        function s = good()
            s = struct('url', 'https://example.org/upload.php', ...
                       'siteID', 'site_a-1', 'token', 'tok123');
        end

        function setUrl(cfg, value)
            % Anonymous functions cannot assign, so this wraps the assignment.
            cfg.url = value;
        end
    end

    methods (Access = private)
        function f = writeJson(tc, s, name)
            % Write a struct (encoded as JSON) or raw text to a file in the scratch folder
            if nargin < 3
                name = 'cfg.json';
            end
            if ~ischar(s)
                s = jsonencode(s);
            end
            f = fullfile(tc.Dir, name);
            fid = fopen(f, 'w');
            fwrite(fid, s);
            fclose(fid);
        end
    end
end
