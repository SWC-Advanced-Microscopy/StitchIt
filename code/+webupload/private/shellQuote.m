function quoted = shellQuote(text)
    % Quote text as one /bin/sh word
    %
    % function quoted = webupload.shellQuote(text)
    %
    % Purpose
    % Inside single quotes the shell reads nothing specially, so only a ' in the text needs
    % care: it is written as '\'' (close the quote, an escaped quote, reopen).
    %
    % Inputs
    % text - char row vector.
    %
    % Outputs
    % quoted - the text in single quotes.

    quoted = ['''', strrep(text, '''', '''\'''''), ''''];
end % shellQuote
