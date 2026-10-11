function wrapped = inBinSh(cmd)
    % Command line that runs cmd under /bin/sh whatever shell MATLAB's system() uses
    %
    % function wrapped = inBinSh(cmd)
    %
    % Purpose
    % Private to +webupload. On unix MATLAB's system() hands the line to $MATLAB_SHELL or
    % $SHELL, which can be csh or tcsh, where syntax such as 2>&1 and (a; b) differs. The
    % background upload writes its commands in sh syntax, so they are run as
    % /bin/sh -c '<cmd>'; the outer quoting is a plain single-quoted word, valid in every
    % shell.
    %
    % Inputs
    % cmd - command in sh syntax, char row vector.
    %
    % Outputs
    % wrapped - the command line to give to system(), as char.

    wrapped = ['/bin/sh -c ', shellQuote(cmd)];
end % inBinSh
