function out = findIncompleteStacks
%
% Since around ScanImage Basic 2021, there are rare cases of the
% final image plane being missing in a small number of tiles. This
% function looks through all acquired stacks and returns a list of
% any with missing tiles. The results are written to a log file and
% also returned to screen.
%
% Return empty if failed to run. Otherwise returns 0 if no missing data
% found. If missing data are found, we return


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

u_fileSizes = unique(out.Var1);

if length(u_fileSizes) == 1
    % Then there are no stacks with missing data
    out = 0;
    return
end

if length(u_fileSizes)>2
    % This is not covered as a case
    fprintf('%s -- It seems like there are three different classes of stack size. Something is very wrong!\n', mfilename)
    u_fileSizes
end


% Otherwise there must be two file sizes and the smaller will be that which has missing data. The
% missing data will be the last plane. We write this information to the folder, display to screen,
% and return a list of paths with missing data to the CLI.

missing_inds = find(out.Var1 ~= u_fileSizes(end));
missing_paths = out.Var2(missing_inds)

msg = sprintf('%s\n\nfindIncompleteStacks identified %d/%d z-stacks as having a missing plane:\n', ...
            datestr(now,'dd-mm-yyyy, HH:MM:SS'), length(missing_inds), length(out.Var1));


missing_paths_str = sprintf('%s\n',missing_paths{:});

msg = [msg,missing_paths_str];


fid = fopen('stacks_with_missing_final_planes.txt','w+');
fprintf(fid,msg);
fclose(fid);


out = missing_paths_str(1:end-1); % because last line is empty
