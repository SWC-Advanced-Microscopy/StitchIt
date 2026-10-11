classdef BackgroundUploadTest < matlab.unittest.TestCase
    % Tests for the 'Background' option: webupload.backgroundCommand, webupload.curlConfigText,
    % and postZip / zipAndPost with an injected launcher, so no process is started. The last
    % test starts a real curl against a local listener (tests/background_listener.py) and runs
    % only on unix with python3 and curl installed. The Windows command is checked as a string
    % only.

    properties
        Dir
        CfgDir
        Commands = {}      % every command the fake launcher was given
        LaunchStatus = 0   % status the fake launcher returns for the launch command
        CurlStatus = 0     % status the fake launcher returns for the "is curl installed" check
    end

    properties (Constant)
        Token = 'SECRETTOKEN123'
    end

    methods (TestClassSetup)
        function addPackageToPath(tc)
            tc.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(fileparts(mfilename('fullpath')), '..')));
        end
    end

    methods (TestMethodSetup)
        function makeDirs(tc)
            fx = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Dir = fx.Folder;
            fx = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.CfgDir = fx.Folder;
            tc.Commands = {};
            tc.LaunchStatus = 0;
            tc.CurlStatus = 0;
        end
    end

    methods (Test)
        % ---- backgroundCommand: pure string composition
        function unixCommandRunsCurlThenRemovesFiles(tc)
            cmd = webupload.backgroundCommand('/tmp/a b/c.curl', '/tmp/z.zip', false);
            tc.verifyEqual(cmd, ...
                ['(curl -q -K ''/tmp/a b/c.curl''; rm -f ''/tmp/a b/c.curl'' ''/tmp/z.zip'') ', ...
                 '> /dev/null 2>&1 &']);
        end

        function unixCommandEscapesSingleQuotes(tc)
            cmd = webupload.backgroundCommand('/tmp/it''s/c.curl', '/tmp/z.zip', false);
            tc.verifyTrue(contains(cmd, '''/tmp/it''\''''s/c.curl'''));
        end

        function pcCommandStartsDetachedCmdAndDeletesFiles(tc)
            cmd = webupload.backgroundCommand('C:\Users\a b\c.curl', 'C:\Users\a b\z.zip', true);
            tc.verifyEqual(cmd, ...
                ['start "" /B cmd /c "curl.exe -q -K "C:\Users\a b\c.curl" & ', ...
                 'del /q "C:\Users\a b\c.curl" "C:\Users\a b\z.zip"" <NUL >NUL 2>&1']);
        end

        function pcCommandRejectsCharactersCmdWouldReinterpret(tc)
            for bad = {'C:\50%\c.curl', 'C:\a"b\c.curl', 'C:\a&b\c.curl', 'C:\a|b\c.curl', ...
                       'C:\a<b\c.curl', 'C:\a>b\c.curl', 'C:\a^b\c.curl', 'C:\a(b)\c.curl'}
                tc.verifyError(@() webupload.backgroundCommand(bad{1}, 'C:\z.zip', true), ...
                    'webupload:badPath');
            end
        end

        % ---- curlConfigText: pure
        function configHasEveryFieldAndTheToken(tc)
            txt = webupload.curlConfigText(tc.makeCfg(), 'mic_1', 'acq', '/tmp/z.zip', 5, 20, '/dev/null');
            lines = strsplit(strtrim(txt), newline);
            expected = { ...
                'url = "https://x.example/up.php"'
                'header = "Authorization: Bearer SECRETTOKEN123"'
                'form-string = "site_id=site_a"'
                'form-string = "microscope_id=mic_1"'
                'form-string = "source=acq"'
                'form = "data=@\"/tmp/z.zip\";type=application/zip;filename=system_data.zip"'
                'proto = "=https"'
                'http1.1'
                'header = "Expect:"'
                'connect-timeout = 5'
                'max-time = 20'
                'output = "/dev/null"'
                'silent'}';
            tc.verifyEqual(lines(:)', expected);
        end

        function configEscapesBackslashesAndQuotesInPaths(tc)
            txt = webupload.curlConfigText(tc.makeCfg(), 'mic_1', 'acq', ...
                'C:\Users\a "b"\z.zip', 5, 20, 'NUL');
            % \ and " are escaped once for curl's form parser, then again for the config file
            tc.verifyTrue(contains(txt, ...
                ['form = "data=@\"C:\\\\Users\\\\a \\\"b\\\"\\\\z.zip\";', ...
                 'type=application/zip;filename=system_data.zip"']));
        end

        function configRejectsControlCharacters(tc)
            tc.verifyError(@() webupload.curlConfigText(tc.makeCfg(), 'mic_1', 'acq', ...
                sprintf('/tmp/a\nb.zip'), 5, 20, '/dev/null'), 'webupload:badConfigValue');
        end

        % ---- postZip with an injected launcher
        function defaultResultHasBackgroundFalse(tc)
            res = webupload.postZip(tc.makeZip(), tc.makeCfg('url', 'http://127.0.0.1:1/upload.php'), 'mic_1', 'acq');
            tc.verifyFalse(res.background);
        end

        function backgroundValidationIsUnchanged(tc)
            zipPath = tc.makeZip();
            cfg = tc.makeCfg();
            launcher = @tc.fakeLauncher;
            cases = {{zipPath, cfg, '', 'acq'}, {zipPath, cfg, 'mic_1', 'bogus'}, ...
                     {zipPath, [], 'mic_1', 'acq'}, {fullfile(tc.Dir, 'no.zip'), cfg, 'mic_1', 'acq'}};
            for ii = 1:numel(cases)
                res = webupload.postZip(cases{ii}{:}, 'Background', true, 'Launcher', launcher);
                tc.verifyFalse(res.ok);
                tc.verifyFalse(res.background);
            end
            tc.verifyEmpty(tc.Commands, 'nothing may be launched when validation fails');
        end

        function backgroundLaunchesAndReturnsAtOnce(tc)
            tc.assumeTrue(isunix, 'parses the unix command');
            zipPath = tc.makeZip();
            res = webupload.postZip(zipPath, tc.makeCfg(), 'mic_1', 'acq', ...
                'Background', true, 'Launcher', @tc.fakeLauncher);
            tc.verifyTrue(res.ok);
            tc.verifyTrue(res.background);
            tc.verifyTrue(isnan(res.httpStatus));
            tc.verifyEqual(res.message, 'Upload started in background; outcome not checked');
            tc.verifyNumElements(tc.Commands, 2, 'a curl check, then the launch');
            tc.verifyTrue(isfile(zipPath), 'postZip must leave the zip for the launched command');
            tc.deleteLaunchedConfig();
        end

        function tokenNeverOnACommandLine(tc)
            tc.assumeTrue(isunix, 'parses the unix command');
            webupload.postZip(tc.makeZip(), tc.makeCfg(), 'mic_1', 'acq', ...
                'Background', true, 'Launcher', @tc.fakeLauncher);
            for ii = 1:numel(tc.Commands)
                tc.verifyFalse(contains(tc.Commands{ii}, BackgroundUploadTest.Token));
            end
            tc.deleteLaunchedConfig();
        end

        function configFileHoldsTokenAndIsOwnerOnly(tc)
            tc.assumeTrue(isunix);
            webupload.postZip(tc.makeZip(), tc.makeCfg(), 'mic_1', 'acq', ...
                'Background', true, 'Launcher', @tc.fakeLauncher, 'ConnectTimeout', 3, ...
                'ResponseTimeout', 9);
            cfgFile = tc.launchedConfigPath();
            txt = fileread(cfgFile);
            tc.verifyTrue(contains(txt, 'Bearer SECRETTOKEN123'));
            tc.verifyTrue(contains(txt, 'connect-timeout = 3'));
            tc.verifyTrue(contains(txt, 'max-time = 9'));
            [~, attr] = fileattrib(cfgFile);
            tc.verifyEqual(double([attr.GroupRead attr.GroupWrite attr.UserRead attr.UserWrite ...
                attr.OtherRead attr.OtherWrite]), [0 0 1 1 0 0]);
            delete(cfgFile);
        end

        function missingCurlFailsWithoutLaunching(tc)
            tc.CurlStatus = 1;
            res = webupload.postZip(tc.makeZip(), tc.makeCfg(), 'mic_1', 'acq', ...
                'Background', true, 'Launcher', @tc.fakeLauncher);
            tc.verifyFalse(res.ok);
            tc.verifyFalse(res.background);
            tc.verifyTrue(contains(res.message, 'curl'));
            tc.verifyNumElements(tc.Commands, 1);
        end

        function failedLaunchFailsAndRemovesConfig(tc)
            tc.assumeTrue(isunix, 'parses the unix command');
            tc.LaunchStatus = 127;
            res = webupload.postZip(tc.makeZip(), tc.makeCfg(), 'mic_1', 'acq', ...
                'Background', true, 'Launcher', @tc.fakeLauncher);
            tc.verifyFalse(res.ok);
            tc.verifyFalse(res.background);
            tc.verifyFalse(contains(res.message, BackgroundUploadTest.Token));
            tc.verifyFalse(isfile(tc.launchedConfigPath()), 'the config holds the token');
        end

        function launcherThatThrowsIsReportedNotThrown(tc)
            res = webupload.postZip(tc.makeZip(), tc.makeCfg(), 'mic_1', 'acq', ...
                'Background', true, 'Launcher', @(~) error('fake:boom', 'tok SECRETTOKEN123'));
            tc.verifyFalse(res.ok);
            tc.verifyFalse(contains(res.message, BackgroundUploadTest.Token));
        end

        function backgroundMustBeLogicalScalar(tc)
            res = webupload.postZip(tc.makeZip(), tc.makeCfg(), 'mic_1', 'acq', ...
                'Background', 'yes', 'Launcher', @tc.fakeLauncher);
            tc.verifyFalse(res.ok);
            tc.verifyEmpty(tc.Commands);
        end

        function guardRunsItsTaskUnlessDisarmed(tc)
            marker = fullfile(tc.Dir, 'ran.txt');
            task = @() fclose(fopen(marker, 'w'));
            g = webupload.CleanupGuard(task);
            clear g
            tc.verifyTrue(isfile(marker));
            delete(marker);
            g = webupload.CleanupGuard(task);
            g.disarm();
            clear g
            tc.verifyFalse(isfile(marker));
        end

        function guardIgnoresAFailingTask(tc)
            g = webupload.CleanupGuard(@() error('x:y', 'boom'));
            tc.verifyWarningFree(@() delete(g));
        end

        % ---- zipAndPost: who owns the zip
        function zipAndPostLeavesZipToTheLaunchedCommand(tc)
            tc.assumeTrue(isunix, 'parses the unix command');
            folder = tc.makeStageFolder();
            res = webupload.zipAndPost(folder, tc.makeCfg(), 'mic_1', 'acq', ...
                'Background', true, 'Launcher', @tc.fakeLauncher);
            tc.verifyTrue(res.ok);
            [~, zipPath] = tc.launchedPaths();
            tc.verifyTrue(isfile(zipPath));
            delete(zipPath);
            tc.deleteLaunchedConfig();
        end

        function zipAndPostDeletesZipWhenLaunchFails(tc)
            tc.assumeTrue(isunix, 'parses the unix command');
            folder = tc.makeStageFolder();
            tc.LaunchStatus = 1;
            res = webupload.zipAndPost(folder, tc.makeCfg(), 'mic_1', 'acq', ...
                'Background', true, 'Launcher', @tc.fakeLauncher);
            tc.verifyFalse(res.ok);
            [~, zipPath] = tc.launchedPaths();
            tc.verifyFalse(isfile(zipPath));
        end

        function stringZipPathGivesTheSameCommandAsCharPath(tc)
            tc.assumeTrue(isunix, 'parses the unix command');
            zipPath = tc.makeZip();
            webupload.postZip(string(zipPath), tc.makeCfg(), 'mic_1', 'acq', ...
                'Background', true, 'Launcher', @tc.fakeLauncher);
            tc.verifyTrue(contains(tc.Commands{end}, ['''' zipPath '''']));
            tc.verifyTrue(contains(fileread(tc.launchedConfigPath()), zipPath));
            tc.deleteLaunchedConfig();
        end

        function backgroundReturnsBeforeASlowServerAnswers(tc)
            tc.assumeTrue(isunix, 'needs a unix shell');
            tc.assumeTrue(system('command -v curl >/dev/null 2>&1') == 0, 'curl not installed');
            tc.assumeTrue(system('command -v python3 >/dev/null 2>&1') == 0, 'python3 not installed');
            portFile = fullfile(tc.Dir, 'port.txt');
            prefix = fullfile(tc.Dir, 'req');
            script = fullfile(fileparts(mfilename('fullpath')), 'background_listener.py');
            system(sprintf('python3 -I ''%s'' ''%s'' ''%s'' 6 > /dev/null 2>&1 &', script, portFile, prefix));
            tc.addTeardown(@() system(sprintf('pkill -f ''%s''', script)));
            tc.verifyTrue(BackgroundUploadTest.waitFor(@() isfile(portFile)), 'listener did not start');
            cfg = tc.makeCfg('url', ['http://127.0.0.1:' strtrim(fileread(portFile)) '/upload.php']);
            folder = tc.makeStageFolder();
            tic
            res = webupload.zipAndPost(folder, cfg, 'mic_1', 'acq', 'Background', true, ...
                'Launcher', @tc.realLauncher);
            elapsed = toc;
            tc.verifyTrue(res.ok);
            tc.verifyLessThan(elapsed, 3, 'the server answers only after 6 s');
            [cfgPath, zipPath] = tc.launchedPaths();
            tc.verifyTrue(BackgroundUploadTest.waitFor(@() ~isfile(cfgPath) && ~isfile(zipPath)));
        end

        % ---- end to end against a local listener
        function realCurlUploadArrivesWithContentLengthAndTidiesUp(tc)
            tc.assumeTrue(isunix, 'needs a unix shell');
            tc.assumeTrue(system('command -v curl >/dev/null 2>&1') == 0, 'curl not installed');
            tc.assumeTrue(system('command -v python3 >/dev/null 2>&1') == 0, 'python3 not installed');

            portFile = fullfile(tc.Dir, 'port.txt');
            prefix = fullfile(tc.Dir, 'req');
            script = fullfile(fileparts(mfilename('fullpath')), 'background_listener.py');
            system(sprintf('python3 -I ''%s'' ''%s'' ''%s'' > /dev/null 2>&1 &', script, portFile, prefix));
            tc.addTeardown(@() system(sprintf('pkill -f ''%s''', script)));
            tc.verifyTrue(BackgroundUploadTest.waitFor(@() isfile(portFile)), 'listener did not start');
            port = strtrim(fileread(portFile));

            folder = tc.makeStageFolder();
            cfg = tc.makeCfg('url', ['http://127.0.0.1:' port '/upload.php']);
            res = webupload.zipAndPost(folder, cfg, 'mic_1', 'acq', 'Background', true, ...
                'Launcher', @tc.realLauncher);
            tc.verifyTrue(res.ok);
            tc.verifyTrue(res.background);

            tc.verifyTrue(BackgroundUploadTest.waitFor(@() isfile([prefix '.hdr'])), ...
                'the upload never arrived');
            hdr = fileread([prefix '.hdr']);
            tc.verifyTrue(contains(hdr, 'authorization: Bearer SECRETTOKEN123'));
            tc.verifyFalse(contains(hdr, 'transfer-encoding'), 'must not be chunked');
            len = str2double(regexp(hdr, 'content-length: (\d+)', 'tokens', 'once'));
            fid = fopen([prefix '.body'], 'r');
            bytes = fread(fid, Inf, '*uint8')';
            fclose(fid);
            body = char(bytes);
            tc.verifyEqual(len, numel(bytes));
            for field = {'site_id', 'microscope_id', 'source', 'data'}
                tc.verifyTrue(contains(body, ['name="' field{1} '"']), field{1});
            end
            tc.verifyTrue(contains(body, sprintf('name="site_id"\r\n\r\nsite_a')));
            tc.verifyTrue(contains(body, sprintf('name="microscope_id"\r\n\r\nmic_1')));
            tc.verifyTrue(contains(body, sprintf('name="source"\r\n\r\nacq')));
            tc.verifyTrue(contains(body, 'filename="system_data.zip"'));
            tc.verifyTrue(contains(body, 'application/zip'));

            [cfgPath, zipPath] = tc.launchedPaths();
            gone = BackgroundUploadTest.waitFor(@() ~isfile(cfgPath) && ~isfile(zipPath));
            tc.verifyTrue(gone, 'zip and curl config must be removed after curl exits');
        end

        function realCurlFailureStillRemovesZipAndConfig(tc)
            tc.assumeTrue(isunix, 'needs a unix shell');
            tc.assumeTrue(system('command -v curl >/dev/null 2>&1') == 0, 'curl not installed');
            folder = tc.makeStageFolder();
            % Port 1 on localhost refuses the connection at once
            cfg = tc.makeCfg('url', 'http://127.0.0.1:1/upload.php');
            res = webupload.zipAndPost(folder, cfg, 'mic_1', 'acq', 'Background', true, ...
                'Launcher', @tc.realLauncher);
            tc.verifyTrue(res.ok, 'a failed upload is invisible by design');
            [cfgPath, zipPath] = tc.launchedPaths();
            gone = BackgroundUploadTest.waitFor(@() ~isfile(cfgPath) && ~isfile(zipPath));
            tc.verifyTrue(gone);
        end
    end

    methods (Static, Access = private)
        function ok = waitFor(cond)
            % Poll cond for up to 15 s
            ok = false;
            for ii = 1:150
                if cond()
                    ok = true;
                    return
                end
                pause(0.1)
            end
        end
    end

    methods (Access = private)
        function [status, out] = fakeLauncher(tc, cmd)
            tc.Commands{end+1} = cmd;
            out = '';
            if contains(cmd, 'command -v') || contains(cmd, 'where ')
                status = tc.CurlStatus;
            else
                status = tc.LaunchStatus;
            end
        end

        function [status, out] = realLauncher(tc, cmd)
            tc.Commands{end+1} = cmd;
            [status, out] = system(cmd);
        end

        function [cfgPath, zipPath] = launchedPaths(tc)
            % The two paths in the last recorded unix launch command
            tok = regexp(tc.Commands{end}, 'rm -f ''([^'']*)'' ''([^'']*)''', 'tokens', 'once');
            cfgPath = tok{1};
            zipPath = tok{2};
        end

        function cfgPath = launchedConfigPath(tc)
            cfgPath = tc.launchedPaths();
        end

        function deleteLaunchedConfig(tc)
            cfgPath = tc.launchedConfigPath();
            if isfile(cfgPath)
                delete(cfgPath)
            end
        end

        function cfg = makeCfg(tc, varargin)
            s = struct('url', 'https://x.example/up.php', ...
                       'siteID', 'site_a', 'token', BackgroundUploadTest.Token);
            for ii = 1:2:numel(varargin)
                s.(varargin{ii}) = varargin{ii+1};
            end
            f = fullfile(tc.CfgDir, 'cfg.json');
            fid = fopen(f, 'w');
            fwrite(fid, jsonencode(s));
            fclose(fid);
            cfg = webupload.webConfig(f);
        end

        function writeFile(~, path)
            fid = fopen(path, 'w'); fwrite(fid, 'x'); fclose(fid);
        end

        function folder = makeStageFolder(tc)
            % A folder holding the two files the server requires
            folder = fullfile(tc.Dir, 'stage');
            mkdir(folder);
            tc.writeFile(fullfile(folder, 'status.json'));
            tc.writeFile(fullfile(folder, 'recipe.yml'));
        end

        function zipPath = makeZip(tc)
            tc.writeFile(fullfile(tc.Dir, 'a.txt'));
            zipPath = fullfile(tc.Dir, 'x.zip');
            zip(zipPath, 'a.txt', tc.Dir);
        end
    end
end
