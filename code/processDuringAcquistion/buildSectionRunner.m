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

curN=generateTileIndex;


while ~exist('./FINISHED','file')
    t=generateTileIndex;
    if t~=curN
        curN=t;
        buildSectionPreview([],chan)
    end
    pause(5)
end


