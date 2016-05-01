function writeSimpleYAML(s, filePath)
% Write a structure as a YAML file
%
% function writeSimpleYAML(s, filePath)
%
% Purpose
% Converts a simple, entirely scalar struct (which can have
% fields which are themselves structs) in to a YAML file.



if ~isstruct(s)||numel(s)>1
    error('Must be a structure scalar')
end

if isempty(strfind(filePath, '.yml'))
    filePath=[filePath, '.yml'];
end
fid=fopen(filePath, 'w');
if fid==-1
    error('File could not be opened. Perhaps you do not have permission to write to this directory: %s',filePath)
end

writeYamlEntry(fid,s)
fclose(fid);
end

function writeYamlEntry(fid,s, indentLevel)
    if nargin<3||isempty(indentLevel)
        indentLevel=0;
    end
    
    f=fieldnames(s);
       
    for ii=1:numel(f)
        
        if indentLevel>0
            fprintf(fid, repmat(' ', 1,4*indentLevel));
        end
        
        thisVal=s.(f{ii});
        if isstruct(thisVal)
            fprintf(fid, sprintf('%s:\n', f{ii}));
            if isscalar(thisVal)
                writeYamlEntry(fid, thisVal, indentLevel+1)
            else
                writeYamlStructArrayEntry(fid, thisVal, indentLevel+1)
            end
        elseif ischar(thisVal)
            fprintf(fid, '%s: %s', f{ii}, thisVal);
        elseif isnumeric(thisVal)
            fprintf(fid, '%s: %s', f{ii}, mat2str(thisVal));
        elseif iscell(thisVal)
            if all(cellfun(@isstr,thisVal)) %hand a cell array of strings
                tmp=sprintf('%s,',thisVal{:});
                tmp(end)=[];
                tmp=['{',tmp,'}'];
                fprintf(fid,'%s: %s', f{ii}, tmp);
            else
                error('Can only handle cell array of strings if value is a cell array')
            end                
        else
            error('Unknown field type:%s', f{ii})
        end
        fprintf(fid, '\n');
    end
end

function writeYamlStructArrayEntry(fid,s, indentLevel)
    if nargin<3||isempty(indentLevel)
        indentLevel=0;
    end
    
    for jj=1:numel(s)
        if indentLevel>0
            fprintf(fid, repmat(' ', 1,4*indentLevel));
        end
        
        fprintf(fid, '-\n');
        
        f=fieldnames(s);
        
        for ii=1:numel(f)
            
            if indentLevel>0
                fprintf(fid, repmat(' ', 1,4*(indentLevel+1)));
            end
            
            if isnumeric(s(jj).(f{ii}))
                fprintf(fid, '%s: %s', f{ii}, mat2str(s(jj).(f{ii})));
            elseif ischar(s(jj).(f{ii}))
                fprintf(fid, '%s: %s', f{ii}, s(jj).(f{ii}));
            elseif isstruct(s(jj).(f{ii}))
                fprintf(fid, sprintf('%s:\n', f{ii}));
                writeYamlEntry(fid,s(jj).(f{ii}), indentLevel+1+1)
            end
            fprintf(fid, '\n');
        end
    end
end
