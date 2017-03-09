function cidreIllumcorrection
% default post acquisition function. 
%
% You may write your own and have it run via the INI file. 
%
%
% Rob Campbell - Basel 2015

% read info from Mosaic.txt 
M=readMetaData2Stitchit;

%check for and fix missing tiles if this was a TissueCyte acquisition
if strcmp(M.System.type,'TissueCyte')
	missingTiles=identifyMissingTilesInDir('rawData',0);
else
	missingTiles = -1;
end

if iscell(missingTiles) && ~isempty(missingTiles)
	fname='missingTiles.mat';
	fprintf('Found and fixed %d missing tiles. Saving missing tile list to %s\n', ...
		length(missingTiles), fname);
	save(fname,'missingTiles')
elseif iscell(missingTiles) && isempty(missingTiles)
	fprintf('Searched for missing tiles but did not find any\n')
elseif ~iscell(missingTiles) && missingTiles == -1
	%nothing happens. No TissueCyte.
end


% calculate background model for illumination correction with CIDRE
for thisChan=chansToStitch 
    tic;
     % source directory name is adjusted to the Tissue way of saving
    source = sprintf('./rawData/*_0%i.tif',thisChan);
    destination = './CIDRE_rawData/';
    [~] = cidre(source, 'destination',destination);
    t=toc/60;
    fprintf('Time for one channel is %i minutes\n',t);
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

