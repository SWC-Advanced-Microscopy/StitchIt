function [offset] = getOffset(chan, redo)
% Get offset value for a channel
%
% function [offset]=getOffset(chan)
%
% PURPOSE
% Load or calculate the offset. If the offset file already exists, load it.
% Otherwise, read all tileStats and take the median of the GMM fit to have
% a single offset per channel for the acquisition
%
%
% INPUTS (required)
% chan - channel to load - default to 2
% redo - if true, ignore offset file and overwrite it - default to false
%
%
%
% OUTPUTS
% offset - the offset based on the GMM fit
%
%


if ~exist('chan', 'var') || isempty(chan)
    chan = 2;
end
if ~exist('redo', 'var') || isempty(redo)
    redo=false;
end

%Load ini file variables
userConfig=readStitchItINI;

offsetFile = fullfile(userConfig.subdir.rawDataDir, userConfig.subdir.preProcessDir, ...
    sprintf('offset_ch%.0f.mat', chan));

if exist(offsetFile,'file') && ~redo
    load(offsetFile, 'offset');
    return
end

% we actually need to do stuff
tileStats = stitchit.tools.loadAllTileStatsFiles(chan);
offset = median([tileStats.offsetDimest]);
save(offsetFile, 'offset');
end

