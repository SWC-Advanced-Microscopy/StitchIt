function cmd = backgroundCommand(cfgPath, zipPath, isPC)
    % Shell command that runs curl detached, then deletes the curl config and the zip
    %
    % function cmd = webupload.backgroundCommand(cfgPath, zipPath, isPC)
    %
    % Purpose
    % Composes the command string that webupload.postZip hands to system() when called with
    % 'Background', true. Pure, so both the unix and the Windows form can be tested on one
    % machine. The token is in the curl config file (webupload.curlConfigText), never in the
    % command. The command ends with the deletion of the config and zip, so they are removed
    % whether curl succeeds or fails.
    %
    % Unix:    (curl -q -K 'cfg'; rm -f 'cfg' 'zip') > /dev/null 2>&1 &
    % Windows: start "" /B cmd /c "curl.exe -q -K "cfg" & del /q "cfg" "zip"" <NUL >NUL 2>&1
    %
    % -q must be the first curl option: it stops curl reading ~/.curlrc (or $CURL_HOME),
    % which could otherwise add a proxy, redirect-following or another header to a request
    % that carries the token. The Windows form needs curl.exe (Windows 10 and later); the
    % redirections stop the started process holding MATLAB's stdin and stdout, so system()
    % is expected to stop system() waiting for it (not yet checked on a Windows machine).
    % The unix string is written in sh syntax: webupload.postZip runs it as /bin/sh -c '...',
    % because MATLAB's system() uses $MATLAB_SHELL or $SHELL, which may be csh or tcsh.
    % This is best effort: a zero status from the launcher shows the shell started, not that
    % curl did.
    %
    % Inputs
    % cfgPath - path of the curl config file (char or string).
    % zipPath - path of the zip that the config uploads (char or string).
    % isPC    - true for the Windows form, false for the unix form.
    %
    % Outputs
    % cmd - the command, as a char row vector.

    cfgPath = char(cfgPath);
    zipPath = char(zipPath);
    if isPC
        % Inside double quotes cmd.exe still reads %VAR% (and !VAR! if delayed expansion is
        % on); the other characters below could end the quoting or start another command.
        % A " cannot be in a Windows path anyway.
        for path = {cfgPath, zipPath}
            if any(ismember(path{1}, '%"&|<>^()!'))
                error('webupload:badPath', ['A path containing any of %% " & | < > ^ ( ) ! ', ...
                    'cannot be passed safely to cmd.exe: %s'], path{1});
            end
        end
        cmd = sprintf(['start "" /B cmd /c "curl.exe -q -K "%s" & del /q "%s" "%s"" ', ...
            '<NUL >NUL 2>&1'], cfgPath, cfgPath, zipPath);
    else
        cfgArg = shellQuote(cfgPath);
        cmd = sprintf('(curl -q -K %s; rm -f %s %s) > /dev/null 2>&1 &', ...
            cfgArg, cfgArg, shellQuote(zipPath));
    end
end % backgroundCommand
