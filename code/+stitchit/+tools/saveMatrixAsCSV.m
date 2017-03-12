function saveMatrixAsCSV(data, fname, colNames)
% Saves the matrix "data" as a CSV file with optional column headings
%
%  function saveMatrixAsCSV(data, fname, colNames)
%
% Purpose
% Uses dlmwrite to write matrix, data, to disk as file "fname". 
% If a third argument is provided, then this is written to the 
% top of the file as a header (column names). 
%
% Inputs
% data - matrix to write to disk
% fname - path to write matrix to
% colName - names of the columns (optional) is a csv string.
% 
%
%
% Rob Campbell, March 2006

if nargin==0
    help(mfilename)
    return
end

if nargin>2
    if length(strsplit(colNames,',')) ~= size(data,2)
        error('Your specified column names do not match the number of columns in "data"')
    end
    fid=fopen(fname,'w');
    fprintf(fid, [colNames,'\n']);
    fclose(fid);
else
    %Wipe the file
    fid=fopen(fname,'w');
    fclose(fid);
end

dlmwrite(fname, data, 'delimiter', ',', 'precision', 6, '-append');

