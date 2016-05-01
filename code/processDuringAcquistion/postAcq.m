function postAcq
% default post acquisition function. 
%
% You may write your own and have it run via the INI file. 
%
%
% Rob Campbell - Basel 2015



%check for and fix missing tiles
missingTiles=identifyMissingTilesInDir('rawData',0);

if ~isempty(missingTiles)
	fname='missingTiles.mat';
	fprintf('Found and fixed %d missing tiles. Saving missing tile list to %s\n', ...
		length(missingTiles), fname);
	save(fname,'missingTiles')
else
	fprintf('Searched for missing tiles but did not find any\n')
end


%-----------------------------------------------------
%attempt to stitch all the data
stitchAllSubDirectories
%-----------------------------------------------------



if exist('generate_MaSIV_list','file')
	fprintf('Making MaSIV section list\n')
	generate_MaSIV_list('stitchedImages_100')
else
	fprintf('Could not find generate_MaSIV_list. SKIPPING\n')
end

