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
    % Unix:    (curl -K 'cfg'; rm -f 'cfg' 'zip') > /dev/null 2>&1 &
    % Windows: start "" /B cmd /c "curl.exe -K "cfg" & del /q "cfg" "zip""
    % The Windows form needs curl.exe (Windows 10 and later).
    %
    % Inputs
    % cfgPath - path of the curl config file.
    % zipPath - path of the zip that the config uploads.
    % isPC    - true for the Windows form, false for the unix form.
    %
    % Outputs
    % cmd - the command, as a char row vector.

    if isPC
        % cmd.exe reads %VAR% even inside double quotes, and a " cannot be a part of a path
        for path = {cfgPath, zipPath}
            if any(path{1} == '%') || any(path{1} == '"')
                error('webupload:badPath', ...
                    'A path containing %% or " cannot be passed safely to cmd.exe: %s', path{1});
            end
        end
        cmd = sprintf('start "" /B cmd /c "curl.exe -K "%s" & del /q "%s" "%s""', ...
            cfgPath, cfgPath, zipPath);
    else
        cfgArg = shellQuote(cfgPath);
        cmd = sprintf('(curl -K %s; rm -f %s %s) > /dev/null 2>&1 &', ...
            cfgArg, cfgArg, shellQuote(zipPath));
    end
end % backgroundCommand

