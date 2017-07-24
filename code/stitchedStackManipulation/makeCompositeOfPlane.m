function makeCompositeOfPlane(expRootDir, scale, channels)
% Produce composite images from the stitched planes. One composite per plane for Omero.
%
%
% function makeComposite(stitchedImageFolder, scale, nbrOfChnls)
%
%
% Purpose
% Convert the stitched images, located in stitchedImageFolder, to a composite image.
% The composites images will be saved in a new folder called "Composite". The 
% composite images can be uploaded directly to Omero. Called from a sample directory.
% Call from sample root directory. 
%
% Inputs
% stitchedImageFolder - String defining the folder where the three stitched channels
%              separated folders are to be found. By default: 'StitchedImages_100'
% scale - Rescaling of the composite stcak. 1 by default. e.g. if 0.5, the 
%         composite images are half the size. 
% channels - which channels to process. If missing handle all channels.
% 
%
% Example
% Three channels of images saved in folders 1, 2 and 3 in the stitched image folder
% called "stitchedImages_100". These will be saved together as composite images that are
% loacted in a new folder in the same directory:
% makeComposite('stitchedImages_100')
%
%
% Notes
% Deletes existing folder if it will clash with the one to be produced.
% 
%
% Laurent Guerard - Basel, 2017


% Check input arguments
if nargin < 1
	stitchedImageFolder = 'stitchedImages_100';
end

if ~exist(stitchedImageFolder,'dir')
	fprintf('ERROR: Can not find folder %s\n',stitchedImageFolder)
    return
end

if nargin < 2
	scale=1;
end

% Choose all channels if no channels argument is defined.
if nargin < 3
	channels = {};
	dirList = dir(stitchedImageFolder);
	dirList = {dirList.name};
	for ii = 1:length(dirList)
		if ~isempty(str2num(dirList{ii}))
			channels = [channels, dirList{ii}];            
		end % if
	end % for ii
end % if nargin < 3


nbrOfChnls = length(channels);

fprintf('%d channels were detected\n', nbrOfChnls);
celldisp(channels)


% Define the output folder
outputFolder = 'stitchedComposite_100'; %Here is where we will write the images

% Wipe folder if already existing then create it
if exist(outputFolder,'dir')
	fprintf('Wiping existing directory %s\n', outputFolder)
	rmdir(outputFolder,'s');
end

mkdir(outputFolder)




% Check if same number of images in all the folders
nbrOfImages = zeros(1,nbrOfChnls);

for ii = 1:nbrOfChnls
    thisDir=fullfile(stitchedImageFolder, channels{ii});
	nbrOfImages(ii) = numel( dir(fullfile(thisDir,'*.tif')) );
    if isempty(nbrOfImages(ii))
        %TOOD: this isn't enough. Need to remove this directory from the list
        fprintf('Directory %s has no TIFF images\n', thisDir)
    end

end


if ~all(nbrOfImages == nbrOfImages(1))
    error('Not the same number of files in each folder !\n')
end
fprintf('There are %d images in each folder\n', nbrOfImages(1));


%Get the list of the images
for ii = 1:nbrOfChnls
   listImages{ii} = dir(fullfile(stitchedImageFolder,num2str(ii),'*.tif'));
end




%Loop and create composite
for ii = 1:nbrOfImages(1)

    fprintf('Creating composite image number %d...\n', ii)
	for jj = 1:nbrOfChnls        
        A{jj} = imread(fullfile(stitchedImageFolder, channels{jj}, listImages{1}(ii).name));
        if jj == 1
            info = imfinfo(fullfile(stitchedImageFolder, channels{jj}, listImages{1}(ii).name));
            bitDepth = info.BitDepth;
            %sampleFormat = info.SampleFormat
        end
    end
    
    %fprintf('%d',bitDepth);
    
    %Write tiff files.
    %/!\ 2 16bit planes images will be seen as 32bit images, readable in Fiji only with Bioformats.
    out = cat(3,A{:});
    
    %Rescale the images
    out = imresize(out,scale);
    
    t = Tiff(fullfile(outputFolder, listImages{1}(ii).name),'w');
    t.setTag('ImageLength',size(out,1));
    t.setTag('ImageWidth', size(out,2));
    t.setTag('Photometric', Tiff.Photometric.MinIsBlack);
    t.setTag('BitsPerSample', bitDepth);
    t.setTag('SamplesPerPixel', size(out,3));
    t.setTag('TileWidth', 128);
    t.setTag('TileLength', 128);
    t.setTag('Compression', Tiff.Compression.None);
    t.setTag('PlanarConfiguration', Tiff.PlanarConfiguration.Chunky);
    t.setTag('Software', 'MATLAB');
    t.setTag('SampleFormat',Tiff.SampleFormat.UInt);
    %fprintf('%d',Tiff.SampleFormat.IEEEFP);
    %imwrite(out, fullfile(outputFolder, listImages{1}(ii).name));
    t.write(out);
    t.close();

end

fprintf('Composite creation finished\n');
