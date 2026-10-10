classdef PostZipTest < matlab.unittest.TestCase
    % Tests for postZip, zipAndPost and interpretResponse.
    % The real upload path needs a live server and is not covered here. Validation of the
    % config and scrubbing of the token are tested in WebConfigTest.

    properties
        Dir
        CfgDir   % holds the config file, kept apart from Dir so it is never zipped
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
            fx = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.CfgDir = fx.Folder;
        end
    end

    methods (Test)
        function unreachableUrlReturnsNotOkWithoutThrowing(tc)
            zipPath = tc.makeZip();
            % Port 1 on localhost: connection refused immediately.
            res = webupload.postZip(zipPath, tc.makeCfg(), 'mic_1', 'acq');
            PostZipTest.verifyNetworkFailure(tc, res);
        end

        function uploadLeavesGlobalRandomStateAlone(tc)
            % The multipart body is built before the refused connection, so this covers it.
            zipPath = tc.makeZip();
            cfg = tc.makeCfg();
            before = rng;
            webupload.postZip(zipPath, cfg, 'mic_1', 'acq');
            tc.verifyEqual(rng, before);
        end

        function zipAndPostFailureIsNonFatal(tc)
            fid = fopen(fullfile(tc.Dir, 'a.txt'), 'w'); fwrite(fid, 'x'); fclose(fid);
            res = webupload.zipAndPost(tc.Dir, tc.makeCfg(), 'mic_1', 'acq');
            PostZipTest.verifyNetworkFailure(tc, res);
        end

        function zipAndPostReportsFolderProblemsWithoutThrowing(tc)
            res = webupload.zipAndPost(tc.Dir, tc.makeCfg(), 'mic_1', 'acq');   % no files
            tc.verifyFalse(res.ok);
            tc.verifyNotEmpty(res.message);
            res = webupload.zipAndPost(fullfile(tc.Dir, 'nope'), tc.makeCfg(), 'mic_1', 'acq');
            tc.verifyFalse(res.ok);
        end

        function zipAndPostSurvivesGarbageCfg(tc)
            % A recognised file makes zipFolder succeed, so postZip is reached.
            fid = fopen(fullfile(tc.Dir, 'a.txt'), 'w'); fwrite(fid, 'x'); fclose(fid);
            for bad = {[], 'str', struct('url', 'https://x'), struct('url', 5, 'siteID', 1, 'token', 7)}
                res = webupload.zipAndPost(tc.Dir, bad{1}, 'mic_1', 'acq');
                tc.verifyFalse(res.ok);
                tc.verifyNotEmpty(res.message);
            end
        end

        function tokenInUrlIsScrubbedFromResults(tc)
            % A refused connection may quote the url, so a url that contains the token
            % must not let the token reach the message.
            fid = fopen(fullfile(tc.Dir, 'a.txt'), 'w'); fwrite(fid, 'x'); fclose(fid);
            cfg = tc.makeCfg('url', ['http://127.0.0.1:1/', PostZipTest.Token]);
            res1 = webupload.postZip(tc.makeZip(), cfg, 'mic_1', 'acq');
            res2 = webupload.zipAndPost(tc.Dir, cfg, 'mic_1', 'acq');
            for res = {res1, res2}
                tc.verifyFalse(res{1}.ok);
                tc.verifyNotEmpty(res{1}.message);
                tc.verifyEmpty(strfind(res{1}.message, PostZipTest.Token));
            end
        end

        function requestCarriesSiteMicroscopeIDAndSource(tc)
            [srv, cfg] = tc.listeningServer('responseTimeout', 2, 'dataTimeout', 2);
            res = webupload.postZip(tc.makeZip(), cfg, 'Scope_A', 'analysis');
            tc.verifyFalse(res.ok);
            request = PostZipTest.readRequest(srv);
            tc.verifyNotEmpty(regexp(request, '(?i)content-length:\s*\d+', 'once'), ...
                'a Content-Length header is what stops IONOS FastCGI dropping the form fields');
            tc.verifyEmpty(regexp(request, '(?i)transfer-encoding:\s*chunked', 'once'), ...
                'a chunked request loses every form field on IONOS FastCGI');
            tc.verifyNotEmpty(regexp(request, 'name="?site_id"?\s+site_a', 'once'));
            tc.verifyNotEmpty(regexp(request, 'name="?microscope_id"?\s+Scope_A', 'once'));
            tc.verifyNotEmpty(regexp(request, 'name="?source"?\s+analysis', 'once'));
            tc.verifyNotEmpty(regexp(request, 'name="?data"?; filename=', 'once'));
            tc.verifyNotEmpty(regexp(request, '(?i)authorization:\s*Bearer ', 'once'));
        end

        function zipAndPostPassesIDsAndSourceThrough(tc)
            [srv, cfg] = tc.listeningServer('responseTimeout', 2, 'dataTimeout', 2);
            fid = fopen(fullfile(tc.Dir, 'acqLog.txt'), 'w'); fwrite(fid, 'x'); fclose(fid);
            webupload.zipAndPost(tc.Dir, cfg, 'mic_1', 'acq');
            request = PostZipTest.readRequest(srv);
            tc.verifyNotEmpty(regexp(request, 'name="?microscope_id"?\s+mic_1', 'once'));
            tc.verifyNotEmpty(regexp(request, 'name="?source"?\s+acq', 'once'));
        end

        function badMicIDOrSourceIsRefusedWithoutSendingARequest(tc)
            [srv, cfg] = tc.listeningServer();
            zipPath = tc.makeZip();
            cases = {'mic_1', 'other'; 'mic_1', 'ACQ'; 'mic_1', ''; 'mic_1', 5; ...
                     '', 'acq'; 'Scope A', 'acq'; '2photon', 'acq'; 'a/b', 'acq'; ...
                     'mic.1', 'acq'; sprintf('mic_1\n'), 'acq'; ['ab'; 'cd'], 'acq'; 7, 'acq'};
            for ii = 1:size(cases, 1)
                res = webupload.postZip(zipPath, cfg, cases{ii, :});
                tc.verifyFalse(res.ok);
                tc.verifyTrue(isnan(res.httpStatus));
                tc.verifyNotEmpty(regexp(res.message, 'microscope ID|source', 'once'));
            end
            % The message says whether the ID was missing or invalid, and shows the value
            res = webupload.postZip(zipPath, cfg, '', 'acq');
            tc.verifySubstring(res.message, 'No microscope ID');
            res = webupload.postZip(zipPath, cfg, '2photon', 'acq');
            tc.verifySubstring(res.message, '"2photon" is invalid');
            res = webupload.postZip(zipPath, cfg, 'mic_1', 'other');
            tc.verifySubstring(res.message, '"other"');
            res = webupload.zipAndPost(tc.Dir, cfg, 'Scope A', 'acq');
            tc.verifyFalse(res.ok);
            tc.verifyFalse(PostZipTest.connectionArrives(srv), 'a request was sent for bad input');
        end

        function stringInputsAreAccepted(tc)
            [srv, cfg] = tc.listeningServer('responseTimeout', 2, 'dataTimeout', 2);
            webupload.postZip(tc.makeZip(), cfg, "mic_1", "acq");
            request = PostZipTest.readRequest(srv);
            tc.verifyNotEmpty(regexp(request, 'name="?microscope_id"?\s+mic_1', 'once'));
            tc.verifyNotEmpty(regexp(request, 'name="?source"?\s+acq', 'once'));
        end

        function missingMicIDAndSourceReturnNotOk(tc)
            cfg = tc.makeCfg();
            res = webupload.postZip(tc.makeZip(), cfg);
            tc.verifyFalse(res.ok);
            res = webupload.zipAndPost(tc.Dir, cfg);
            tc.verifyFalse(res.ok);
        end

        function responseTimeoutOptionOverridesTheConfigForOneCall(tc)
            % The config allows 60 s; the server never answers, so the call must give up
            % at the 1 s override.
            [srv, cfg] = tc.listeningServer('responseTimeout', 60);
            tic;
            res = webupload.postZip(tc.makeZip(), cfg, 'mic_1', 'acq', 'ResponseTimeout', 1);
            tc.verifyLessThan(toc, 20);
            tc.verifyFalse(res.ok);
            tc.verifyTrue(PostZipTest.connectionArrives(srv));
        end

        function connectAndDataTimeoutOptionsAreAccepted(tc)
            % Only checks that the options are accepted and the call still reaches the
            % network; a connect timeout cannot be provoked on a local socket.
            res = webupload.postZip(tc.makeZip(), tc.makeCfg(), 'mic_1', 'acq', ...
                'ConnectTimeout', 5, 'ResponseTimeout', 10, 'DataTimeout', 10);
            PostZipTest.verifyNetworkFailure(tc, res);
        end

        function badTimeoutOptionsAreRefusedWithoutSendingARequest(tc)
            [srv, cfg] = tc.listeningServer();
            zipPath = tc.makeZip();
            bad = {{'ConnectTimeout', -1}, {'ResponseTimeout', 0}, {'ResponseTimeout', 'soon'}, ...
                   {'ConnectTimeout', Inf}, {'DataTimeout', -2}, {'ConnectTimeout', [1 2]}, {'Bogus', 1}, {'ConnectTimeout'}};
            for ii = 1:numel(bad)
                res = webupload.postZip(zipPath, cfg, 'mic_1', 'acq', bad{ii}{:});
                tc.verifyFalse(res.ok);
                tc.verifyNotEmpty(res.message);
            end
            tc.verifyFalse(PostZipTest.connectionArrives(srv), 'a request was sent for bad input');
        end

        function redirectStatusIsNotOkAndSaysSo(tc)
            r = webupload.interpretResponse(302, '');
            tc.verifyFalse(r.ok);
            tc.verifySubstring(r.message, 'redirect');
        end

        function missingZipReturnsNotOk(tc)
            res = webupload.postZip(fullfile(tc.Dir, 'nope.zip'), tc.makeCfg(), 'mic_1', 'acq');
            tc.verifyFalse(res.ok);
            tc.verifyNotEmpty(res.message);
        end

        function badCfgReturnsNotOk(tc)
            res = webupload.postZip('whatever.zip', struct('url', 'https://x'), 'mic_1', 'acq');
            tc.verifyFalse(res.ok);
            tc.verifySubstring(res.message, 'webConfig');
        end

        function status200WithOkBodyIsOk(tc)
            r = webupload.interpretResponse(200, struct('status', 'ok', 'files', {{'a.jpg'}}));
            tc.verifyTrue(r.ok);
            tc.verifyEqual(r.httpStatus, 200);
        end

        function status200OkWithoutFilesIsOk(tc)
            r = webupload.interpretResponse(200, struct('status', 'ok'));
            tc.verifyTrue(r.ok);
        end

        function status200WithErrorBodyIsNotOk(tc)
            r = webupload.interpretResponse(200, struct('status', 'error', 'message', 'boom'));
            tc.verifyFalse(r.ok);
            tc.verifySubstring(r.message, 'boom');
        end

        function errorStatusesAreNotOkAndKeepServerMessage(tc)
            for code = [401 403 413 415 429]
                r = webupload.interpretResponse(code, struct('status', 'error', 'message', 'nope'));
                tc.verifyFalse(r.ok);
                tc.verifyEqual(r.httpStatus, code);
                tc.verifySubstring(r.message, 'nope');
            end
        end

        function nonJsonEmptyAndArrayBodiesAreHandled(tc)
            bodies = {'<html>oops</html>', [], '', struct('status', {'ok', 'ok'}), {1, 2}};
            for ii = 1:numel(bodies)
                r = webupload.interpretResponse(200, bodies{ii});
                tc.verifyFalse(r.ok);
                tc.verifyNotEmpty(r.message);
            end
            r = webupload.interpretResponse(500, '<html>oops</html>');
            tc.verifyEqual(r.httpStatus, 500);
        end
    end

    properties (Constant, Access = private)
        Token = 'SECRET-TOKEN-XYZ'
    end

    methods (Static, Access = private)
        function request = readRequest(srv)
            % Accept the connection the OS buffered for us and read the request text
            srv.setSoTimeout(5000);
            conn = srv.accept();
            closer = onCleanup(@() conn.close());
            in = conn.getInputStream();
            request = char(zeros(1, 0));
            while in.available() > 0
                request(end+1) = char(mod(in.read(), 256)); %#ok<AGROW> small request
            end
            clear closer
        end

        function tf = connectionArrives(srv)
            % True if a client connected to the server socket within half a second
            srv.setSoTimeout(500);
            try
                srv.accept().close();
                tf = true;
            catch err
                % Only the socket timeout means "nobody connected"; anything else is a bug
                if ~(isa(err, 'matlab.exception.JavaException') && ...
                        isa(err.ExceptionObject, 'java.net.SocketTimeoutException'))
                    rethrow(err);
                end
                tf = false;
            end
        end

        function verifyNetworkFailure(tc, res)
            tc.verifyFalse(res.ok);
            tc.verifyTrue(isnan(res.httpStatus));
            tc.verifyNotEmpty(res.message);
            tc.verifyEmpty(strfind(res.message, PostZipTest.Token));
            % The failure must come from the connection, not from our own
            % argument checks or a coding error.
            tc.verifyEmpty(regexp(res.message, ...
                'cfg must|must (start|be)|not found|Undefined|Unrecognized|Invalid', 'once'));
        end
    end

    methods (Access = private)
        function cfg = makeCfg(tc, varargin)
            % A webConfig for a refused localhost port. Name/value pairs override fields
            % of the config file, for example makeCfg('url', 'http://127.0.0.1:1/x').
            s = struct('url', 'http://127.0.0.1:1/upload.php', ...
                       'siteID', 'site_a', 'token', PostZipTest.Token);
            for ii = 1:2:numel(varargin)
                s.(varargin{ii}) = varargin{ii+1};
            end
            f = fullfile(tc.CfgDir, 'cfg.json');
            fid = fopen(f, 'w');
            fwrite(fid, jsonencode(s));
            fclose(fid);
            cfg = webupload.webConfig(f);
        end

        function [srv, cfg] = listeningServer(tc, varargin)
            % A local socket that never answers, and a config pointing at it. The operating
            % system accepts the connection and buffers a small request until we accept()
            % it, so the request can be inspected after postZip has given up.
            tc.assumeTrue(usejava('jvm'), 'needs the Java VM to open a local socket');
            srv = java.net.ServerSocket(0);
            tc.addTeardown(@() srv.close());
            cfg = tc.makeCfg('url', sprintf('http://127.0.0.1:%d/upload.php', srv.getLocalPort()), ...
                             varargin{:});
        end

        function zipPath = makeZip(tc)
            fid = fopen(fullfile(tc.Dir, 'a.txt'), 'w'); fwrite(fid, 'x'); fclose(fid);
            zipPath = fullfile(tc.Dir, 'x.zip');
            zip(zipPath, 'a.txt', tc.Dir);
        end
    end
end
