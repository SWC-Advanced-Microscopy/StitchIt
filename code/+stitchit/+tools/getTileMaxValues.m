function maxVals = getTileMaxValues(IN,depth,n)

% Loop through output of stitchit.tools.loadAllTileStatsFiles and get the n 
% largest means for the defined depth for chan in IN (default 2, defined in
% loadAllTilesStatsFiles)
%
% function maxVals = getTileMaxValues(IN,depth,n)
%
%
% Purpose
% Use to help diagnose changes in gross sample brightness over time
%
% Inputs
% IN - output of loadAllTileStatsFiles
% depth - 1 by default
% n - 10 by default
%
% Outputs
% maxVals - vector of max values
%
%
%
% Rob Campbell - Basel 2016


if nargin<2 || isempty(depth)
    depth=1;
end

if nargin<4 || isempty(depth)
    n=10;
end




maxVals = zeros(length(IN),n);


for ii=1:length(IN)
    m=sort(IN(ii).mu{1,depth},'descend');
    maxVals(ii,:) = m(1:n);
end


maxVals=maxVals(:);
