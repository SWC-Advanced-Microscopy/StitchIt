function out = addMissingDefaultsToFile(fname)
    % Add missing default fields to the INI file, fname
    %
    % function out = addMissingDefaultsToFile(fname)
    %
    % Purpose
    % StitchIt expects to find at least the settings defined in the file
    % stitchitConf_DEFAULT.ini which part of the repo. If the INI file
    % defined by fname is missing fields, these are added add defaults from this file.
    % If the file is writable, it is modified on disk. Otherwise only the defaults are
    % added but the file is unmodified.
    %
    % Inputs
    % fname - path to INI file
    %

    %Load the default INI file
    default = readThisINI('stitchitConf_DEFAULT.ini');

    out = readThisINI(fname);


    %Check that the user INI file contains all the keys that are in the default
    fO=fields(out);
    fD=fields(default);

    % Loop through the structure and add missing fields.
    missingFields = {}; % Store missing fields here to add them into the user INI file if needed.
    for ii=1:length(fD)

        sO = fields(out.(fD{ii}));
        sD = fields(default.(fD{ii}));

        for jj=1:length(sD)
            if isempty(strmatch(sD{jj},sO,'exact'))
               fprintf('Missing field %s.%s in INI file %s. Using default value.\n', ...
                fD{ii}, sD{jj}, which(fname))

               out.(fD{ii}).(sD{jj}) = default.(fD{ii}).(sD{jj});

               missingFields{end+1} = {fD{ii}, sD{jj}};

            end
        end

    end


    % If the user has write access to the file, we modify it.
    if isempty(missingFields) || ~stitchit.tools.isWritable(fname)
        return
    end

    % Get low-level access to the INI files
    D = IniConfig('stitchitConf_DEFAULT.ini');
    L = IniConfig(fname);
    % Add keys, values, and comments from default INI to file defined by fname
    for ii=1:length(missingFields)
        tSection = missingFields{ii}{1};
        tKey = missingFields{ii}{2};
        tValue = default.(tSection).(tKey);

        % Get the comment
        tSection = [ '[',tSection,']' ];
        tComment = D.GetComment(tSection,tKey);

        % Add the key and value
        L.AddKeys(tSection,tKey,tValue);

        % Add the comment (TODO -- it is adding an extra new line)
        L.InsertComment(tComment, {tSection,tKey});

    end

    % Write the new information to the file
    L.WriteFile(fname);
