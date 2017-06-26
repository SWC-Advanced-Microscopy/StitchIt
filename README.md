<img src="https://github.com/BaselLaserMouse/StitchIt/blob/gh-pages/images/rgb_brain_example.jpg" />


# StitchIt and CIDRE

This is a fork of the main stream poject [*StitchIt*](https://github.com/BaselLaserMouse/StitchIt). Here, we integrate [CIDRE](https://github.com/Fouga/cidre)  illumination correction algorithm into the image illumination correction pipeline. 
In odder to use the CIDRE correction you need to add [CIDRE fork](https://github.com/Fouga/cidre) to the matlab path as it is shown in the example.

# Motivation

Nonlinear illumination of an image is a common artifact of any microscope. This artifact is particularly noticable in a tile acquasition system such as [Ragan et al](http://www.nature.com/nmeth/journal/v9/n3/abs/nmeth.1854.html). To adjust image brightness of each tile, one can calculte an average image of the acquired stack. Although this technique works very well on images with ample intensity information, on images with sparce signal more robust solution is required. 

# Example
```Matlab
source_dir = '/DATA_NAME/'; % here you need to have rawData directory with all your data and a Mosaic.txt

addpath(genpath('FULL_PATH/StitchIt/code/')); % add path of the StitchIt(https://github.com/BaselLaserMouse/StitchIt).

addpath(genpath('FULL_PATH/StitchIt_cidre/')); % add path of the CIDRE(https://github.com/Fouga/cidre) 

cd (source_dir);

% maKE INI FILE
if ~exist('stitchitConf.ini')
	makeLocalStitchItConf
end

% read info from Mosaic.txt 
M=readMetaData2Stitchit;

%check for and fix missing tiles if this was a TissueCyte acquisition
if strcmp(M.System.type,'TissueCyte')
    writeBlacktile = 0;
	missingTiles=identifyMissingTilesInDir('rawData',0,0,[],writeBlacktile);
else
	missingTiles = -1;
end

% correct background illumination with cidre
cidreIllumcorrection


% stitch all the data
stitchAllChannels
```
