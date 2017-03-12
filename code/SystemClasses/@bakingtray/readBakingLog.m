function [stagePos,tileCoords]=readBakingLog(fname)
% function [stagePos,tileCoords]=readBakingLog(fname)
%
% Purpose
% Preliminary function to return stage position from bakingTray log file
%
%
% 


if ~exist(fname,'file')
    error('Can not find file %s',fname)
end


%Read tile location from the file
fid = fopen(fname);

tline = fgetl(fid);

stagePos=[];
while ischar(tline)

    tok=regexp(tline,'x=([\d.]+),','tokens');

    if isempty(tok)
        tline=fgetl(fid);
        continue
    end
    x=str2num(tok{1}{1});

    tok=regexp(tline,'y=([\d.]+),','tokens');
    y=str2num(tok{1}{1});
        
    stagePos = [stagePos; [y,x]];

    tline = fgetl(fid);

end


fclose(fid);


%Convert to locations in the grid
tileCoords = zeros(size(stagePos));

u = unique(stagePos(:,1));
for ii=1:length(u)
    f=find(stagePos(:,1)==u(ii));
    tileCoords(f,1)=ii;
end

u = unique(stagePos(:,2));
for ii=1:length(u)
    f=find(stagePos(:,2)==u(ii));
    tileCoords(f,2)=ii;
end

