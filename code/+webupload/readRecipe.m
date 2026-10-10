function [micID, sampleID] = readRecipe(recipePath)
    % Read the microscope ID and the sample ID from a recipe file
    %
    % function [micID, sampleID] = webupload.readRecipe(recipePath)
    %
    % Purpose
    % The microscope ID is the value of ID directly under the top-level SYSTEM key and the
    % sample ID is the value of ID directly under the top-level sample key. Both are found
    % with regexp rather than a YAML parser, so the core has no dependency. Block style
    % ("SYSTEM:" then an indented "ID: x") and flow style ("sample: {ID: x, ...}") are
    % understood. A trailing " #..." comment is dropped, one pair of matching quotes is
    % removed, and surrounding white space is trimmed. A leading UTF-8 byte order mark is
    % ignored. IDs nested deeper, in other sections, or in keys that merely end in "ID" are
    % not matched.
    %
    % The microscope ID is then normalised the way the brainsaw server does it: each space
    % becomes '_', so 'Scope A' is 'Scope_A'. The sample ID keeps its spaces. Whether the
    % microscope ID is valid is checked by postZip, which refuses the upload if it is not.
    %
    % A field that cannot be found gives '' rather than an error.
    %
    % Inputs
    % recipePath - path to the recipe file. Errors with webupload:recipeMissing if it is
    %              not a file.
    %
    % Outputs
    % micID    - normalised microscope ID, or '' if absent or blank.
    % sampleID - sample ID, or '' if absent or blank.

    if ~isfile(recipePath)
        error('webupload:recipeMissing', 'Recipe file not found: %s', recipePath);
    end

    fid = fopen(recipePath, 'r');
    closer = onCleanup(@() fclose(fid)); %#ok<NASGU> runs on scope exit
    bytes = fread(fid, Inf, '*uint8')';
    if numel(bytes) >= 3 && isequal(bytes(1:3), uint8([239 187 191]))
        bytes = bytes(4:end);
    end
    text = char(bytes);

    micID = strrep(yamlID(text, 'SYSTEM'), ' ', '_');
    sampleID = yamlID(text, 'sample');
end % readRecipe


function id = yamlID(text, section)
    % The value of the ID key directly under a top-level YAML key; '' if there is none
    %
    % function id = webupload.readRecipe>yamlID(text, section)
    %
    % Inputs
    % text    - contents of the recipe file.
    % section - name of the top-level key, for example 'SYSTEM'.
    %
    % Outputs
    % id - the cleaned value, or ''.

    % Flow style, "sample: {a: b, ID: x}": ID must follow the brace or a comma
    flow = regexp(text, ['(?m)^', section, ':[ \t]*\{([^}\r\n]*)\}'], 'tokens', 'once');
    if ~isempty(flow)
        tok = regexp(flow{1}, '(?:^|,)[ \t]*ID:([^,]*)', 'tokens', 'once');
    else
        % Block style: the ID key must have the same indent as the first child, so that an
        % ID nested deeper is not matched. Blank lines are part of the block.
        body = regexp(text, ['(?m)^', section, ':[ \t]*\r?\n((?:[ \t]*\r?\n|[ \t]+[^\r\n]*(?:\r?\n|$))*)'], ...
            'tokens', 'once');
        tok = [];
        if ~isempty(body)
            indent = regexp(body{1}, '^(?:[ \t]*\r?\n)*([ \t]+)', 'tokens', 'once');
            if ~isempty(indent)
                tok = regexp(body{1}, ['(?m)^', indent{1}, 'ID:([^\r\n]*)'], 'tokens', 'once');
            end
        end
    end

    id = '';
    if ~isempty(tok)
        id = regexprep(tok{1}, '[ \t]+#.*$', '');
        id = regexprep(id, '^[ \t\r\n]+|[ \t\r\n]+$', '');
        id = regexprep(id, '^([''"])(.*)\1$', '$2');
        id = regexprep(id, '^[ \t\r\n]+|[ \t\r\n]+$', '');
    end
end % yamlID
