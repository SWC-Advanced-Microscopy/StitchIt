function quoted = shellQuote(text)
    % Quote text as one word for the POSIX shell that MATLAB's system() uses on unix
    %
    % function quoted = shellQuote(text)
    %
    % Purpose
    % Private to +webupload. Inside single quotes the shell reads nothing specially, so only
    % a ' in the text needs care: it is written as '\'' (close the quote, an escaped quote,
    % reopen). A string is converted to char first, since the character arithmetic below
    % would otherwise treat it as a string array.
    %
    % Inputs
    % text - char row vector or string scalar.
    %
    % Outputs
    % quoted - the text in single quotes, as char.

    text = char(text);
    quoted = ['''', strrep(text, '''', '''\'''''), ''''];
end % shellQuote
