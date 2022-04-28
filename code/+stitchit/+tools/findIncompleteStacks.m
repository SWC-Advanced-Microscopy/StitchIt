function out = findIncompleteStacks
% Identify stacks with a missing final z--plane
%
% function out = findIncompleteStacks
%
% Purpose
% Since around ScanImage Basic 2021, there are rare cases of the
% final image plane being missing in a small number of tiles. This
% function looks through all acquired stacks and returns a list of
% any with missing tiles. The results are written to a log file and
% also returned to screen.
%
% Outputs
% out - Return empty if failed to run. Otherwise returns 0 if no missing data
% found. If missing data are found, we return a cell array of strings that are
% paths to the files with missing data. Can feed this to patchFailedZstacks to
% add one more z-plane, thus allowing stitching.
%
% Inputs
% None
%
% Rob Campbell - SWC 2022



% Get data and write to a file
temp_name = [tempname,'_findIncomplete'];
cmd = ['find rawData -name ''*-*_*.tif'' -exec ls -l {} \; | awk ''{ print $5, $9 }'' > ',temp_name];


fprintf('Searching for stacks with missing data. This could take some time\n')

status=system(cmd);

if status ~= 0
    fprintf('findIncompleteStacks failed to run shell command\n')
    out = [];
    return
end

out = readtable(temp_name,'Format','%d %s');

% Can not just unique the file sizes as meta-data means there are small differences
% between stacks. So we look for differences greater than one small 50 by 50 image.

f_size = round(out.Var1 / (50^2 * 2));

u_fileSizes = unique(f_size);

if length(u_fileSizes) == 1
    % Then there are no stacks with missing data
    fprintf('All stacks are intact\n')
    out = 0;
    return
end

if length(u_fileSizes)>2
    % This is not covered as a case
    fprintf('%s -- It seems like there are three different classes of stack size. Something is very wrong!\n', mfilename)
    u_fileSizes
    out = -1;
    return
end


% Otherwise there must be two file sizes and the smaller will be that which has missing data. The
% missing data will be the last plane. We write this information to the folder, display to screen,
% and return a list of paths with missing data to the CLI.

missing_inds = find(f_size ~= u_fileSizes(end));
missing_paths = out.Var2(missing_inds);

msg = sprintf('%s\n\nfindIncompleteStacks identified %d/%d z-stacks as having a missing plane:\n', ...
            datestr(now,'dd-mm-yyyy, HH:MM:SS'), length(missing_inds), length(out.Var1));


missing_paths_str = sprintf('%s\n',missing_paths{:});

msg = [msg,missing_paths_str];
fprintf('\n\n%s\n',msg)

fid = fopen('stacks_with_missing_final_planes.txt','w+');
fprintf(fid,msg);
fclose(fid);

% TODO -- will need to report disk sizes and perhaps also determine what is missing.
out = missing_paths;
