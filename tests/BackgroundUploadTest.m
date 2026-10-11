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
                       'C:\a<b\c.curl', 'C:\a>b\c.curl', 'C:\a^b\c.curl', 'C:\a(b)\c.curl', 'C:\a!b\c.curl'}
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

        function guardWarnsAboutAFailingTaskInsteadOfThrowing(tc)
            g = webupload.CleanupGuard(@() error('x:y', 'boom'));
            tc.verifyWarning(@() delete(g), 'webupload:cleanupFailed');
        end

        function configLimitsProtoToTheUrlScheme(tc)
            f = @(url) webupload.curlConfigText(tc.makeCfg('url', url), 'mic_1', 'acq', '/tmp/z.zip', ...
                5, 20, '/dev/null');
            tc.verifyTrue(contains(f('http://127.0.0.1:8080/up.php'), 'proto = "=http"'));
            tc.verifyTrue(contains(f('https://x.example/up.php'), 'proto = "=https"'));
        end

        % ---- zipAndPost: who owns the zip
        function zipAndPostLeavesZipToTheLaunchedCommand(tc)
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
            folder = tc.makeStageFolder();
            tc.LaunchStatus = 1;
            res = webupload.zipAndPost(folder, tc.makeCfg(), 'mic_1', 'acq', ...
                'Background', true, 'Launcher', @tc.fakeLauncher);
            tc.verifyFalse(res.ok);
            [~, zipPath] = tc.launchedPaths();
            tc.verifyFalse(isfile(zipPath));
        end

        function unixCommandsRunInBinShAndWindowsOnesDoNot(tc)
            tc.assumeTrue(isunix, 'the sh form is only used on unix');
            webupload.postZip(tc.makeZip(), tc.makeCfg(), 'mic_1', 'acq', ...
                'Background', true, 'Launcher', @tc.fakeLauncher, 'IsPC', false);
            tc.verifyTrue(all(startsWith(tc.Commands, '/bin/sh -c ''')));
            tc.verifyTrue(contains(tc.Commands{1}, 'command -v curl'));
            tc.verifyTrue(startsWith(BackgroundUploadTest.unwrapSh(tc.Commands{2}), '(curl -q -K '));
            tc.deleteLaunchedConfig();
        end

        function windowsBranchChecksForCurlExeAndStartsDetached(tc)
            webupload.postZip(tc.makeZip(), tc.makeCfg(), 'mic_1', 'acq', ...
                'Background', true, 'Launcher', @tc.fakeLauncher, 'IsPC', true);
            tc.verifyTrue(startsWith(tc.Commands{1}, 'where curl.exe'));
            tc.verifyTrue(startsWith(tc.Commands{2}, 'start "" /B cmd /c "curl.exe -q -K '));
            tc.verifyFalse(contains(tc.Commands{2}, BackgroundUploadTest.Token));
            tc.deleteLaunchedConfig();
        end

        function launchWorksWhenMatlabShellIsTcsh(tc)
            % MATLAB reads MATLAB_SHELL once per session, so a child MATLAB is started with it set
            tc.assumeTrue(isunix, 'needs a unix shell');
            tc.assumeTrue(isfile('/bin/tcsh'), 'tcsh not installed');
            tc.assumeTrue(system('command -v curl >/dev/null 2>&1') == 0, 'curl not installed');
            tc.assumeTrue(isfile(fullfile(matlabroot, 'bin', 'matlab')), 'matlab binary not found');
            [port, prefix] = tc.startListener(0);
            tc.makeCfg('url', ['http://127.0.0.1:' port '/upload.php']);
            cfgFile = fullfile(tc.CfgDir, 'cfg.json');
            folder = tc.makeStageFolder();
            outFile = fullfile(tc.Dir, 'child_out.txt');
            childScript = fullfile(tc.Dir, 'child_run.m');
            fid = fopen(childScript, 'w');
            fprintf(fid, ['addpath(''%s'');\n', ...
                'plain = system(''command -v curl >/dev/null 2>&1'');\n', ...
                'cfg = webupload.webConfig(''%s'');\n', ...
                'res = webupload.zipAndPost(''%s'', cfg, ''mic_1'', ''acq'', ''Background'', true);\n', ...
                'fid = fopen(''%s'', ''w''); fprintf(fid, ''%%d %%d'', plain, res.ok); fclose(fid);\n'], ...
                fullfile(fileparts(mfilename('fullpath')), '..', 'code'), cfgFile, folder, outFile);
            fclose(fid);
            system(sprintf('env MATLAB_SHELL=/bin/tcsh ''%s'' -batch "run(''%s'')" > /dev/null 2>&1', ...
                fullfile(matlabroot, 'bin', 'matlab'), childScript));
            tc.assertTrue(isfile(outFile), 'child MATLAB did not finish');
            childResult = sscanf(fileread(outFile), '%d %d');
            tc.assumeTrue(childResult(1) ~= 0, 'MATLAB_SHELL not used by the child, so this shows nothing');
            tc.verifyEqual(childResult(2), 1, 'the launch must work although tcsh runs system()');
            tc.verifyTrue(BackgroundUploadTest.waitFor(@() isfile([prefix '.hdr'])), 'the upload never arrived');
        end

        function stringZipPathGivesTheSameCommandAsCharPath(tc)
            tc.assumeTrue(isunix, 'parses the unix command');
            zipPath = tc.makeZip();
            webupload.postZip(string(zipPath), tc.makeCfg(), 'mic_1', 'acq', ...
                'Background', true, 'Launcher', @tc.fakeLauncher);
            tc.verifyTrue(contains(BackgroundUploadTest.unwrapSh(tc.Commands{end}), ['''' zipPath '''']));
            tc.verifyTrue(contains(fileread(tc.launchedConfigPath()), zipPath));
            tc.deleteLaunchedConfig();
        end

        function backgroundReturnsBeforeASlowServerAnswers(tc)
            tc.assumeTrue(isunix, 'needs a unix shell');
            tc.assumeTrue(system('command -v curl >/dev/null 2>&1') == 0, 'curl not installed');
            [port, ~] = tc.startListener(6);
            cfg = tc.makeCfg('url', ['http://127.0.0.1:' port '/upload.php']);
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
            [port, prefix] = tc.startListener(0);

            % Over 1 MB, where curl would add 'Expect: 100-continue' unless told not to
            folder = tc.makeStageFolder(1.5e6);
            zipPath = webupload.zipFolder(folder);
            reference = [zipPath '.reference'];
            copyfile(zipPath, reference);
            tc.addTeardown(@() delete(reference));
            cfg = tc.makeCfg('url', ['http://127.0.0.1:' port '/upload.php']);
            res = webupload.postZip(zipPath, cfg, 'mic_1', 'acq', 'Background', true, ...
                'Launcher', @tc.realLauncher);
            tc.verifyTrue(res.ok);
            tc.verifyTrue(res.background);

            tc.verifyTrue(BackgroundUploadTest.waitFor(@() isfile([prefix '.hdr'])), ...
                'the upload never arrived');
            hdr = fileread([prefix '.hdr']);
            tc.verifyTrue(contains(hdr, 'authorization: Bearer SECRETTOKEN123'));
            tc.verifyFalse(contains(hdr, 'transfer-encoding'), 'must not be chunked');
            tc.verifyFalse(contains(hdr, 'expect:'), 'no 100-continue handshake');
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
            fid = fopen(reference, 'r');
            sent = fread(fid, Inf, '*uint8')';
            fclose(fid);
            tc.verifyGreaterThan(numel(sent), 1e6);
            tc.verifyTrue(contains(body, char(sent)), 'the zip arrives byte for byte');

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
        function cmd = unwrapSh(cmd)
            % The sh command inside a /bin/sh -c '...' line
            if startsWith(cmd, '/bin/sh -c ''')
                cmd = strrep(cmd(13:end-1), '''\''''', '''');
            end
        end

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
        function [port, prefix] = startListener(tc, delay)
            % Start tests/background_listener.py on a free local port; killed by PID afterwards
            tc.assumeTrue(system('command -v python3 >/dev/null 2>&1') == 0, 'python3 not installed');
            portFile = fullfile(tc.Dir, 'port.txt');
            prefix = fullfile(tc.Dir, 'req');
            script = fullfile(fileparts(mfilename('fullpath')), 'background_listener.py');
            cmd = sprintf('python3 -I ''%s'' ''%s'' ''%s'' %g > /dev/null 2>&1 & echo $!', ...
                script, portFile, prefix, delay);
            [~, pid] = system(['/bin/sh -c ''' strrep(cmd, '''', '''\''''') '''']);
            pid = strtrim(pid);
            tc.addTeardown(@() system(['kill ' pid ' > /dev/null 2>&1']));
            tc.verifyTrue(BackgroundUploadTest.waitFor(@() isfile(portFile)), 'listener did not start');
            port = strtrim(fileread(portFile));
        end

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
            cmd = BackgroundUploadTest.unwrapSh(tc.Commands{end});
            tok = regexp(cmd, 'rm -f ''([^'']*)'' ''([^'']*)''', 'tokens', 'once');
            if isempty(tok)
                tok = regexp(cmd, 'del /q "([^"]*)" "([^"]*)"', 'tokens', 'once');
            end
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

        function folder = makeStageFolder(tc, imageBytes)
            % A folder holding the two files the server requires, plus an image of random
            % (so incompressible) bytes if imageBytes is given
            folder = fullfile(tc.Dir, 'stage');
            mkdir(folder);
            if nargin > 1
                saved = rng(1);
                data = randi(255, 1, imageBytes, 'uint8');
                rng(saved);
                fid = fopen(fullfile(folder, 'LastCompleteSection.jpg'), 'w');
                fwrite(fid, data);
                fclose(fid);
            end
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
