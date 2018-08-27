function buildSectionRunner(chan)
% Simple function that constantly looks for new data and sends them to the web if found
%
% function buildSectionRunner(chan)
%
% Purpose
% Sends new data to the web when completed directories are found. 
% Aborts when the FINISHED file appears
%
%

if nargin<1
    c=channelsAvailableForStitching;
    chan=c(1);
    fprintf('\n\n * No channel to plot defined.\n * Choosing channel %d to send to web\n\n', chan)
end

curN=generateTileIndex;


while ~exist('./FINISHED','file')
    t=generateTileIndex;
    if t~=curN
        curN=t;
        buildSectionPreview([],chan)
    end
    pause(5)
end


