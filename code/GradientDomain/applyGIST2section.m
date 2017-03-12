function varargout=applyGIST2section(section,chan,saveFname,ind,runInBackGround)
% Conduct GIST "seamless stitching" (seam removal) on a single sitched section
%
% function [im,mask]=applyGIST2section(section,chan,saveFname,ind,runInBackGround)
%
% Purpose
% Remove seams from an already stitched image using a gradient-domain seam
% removal algorithm. For more information on this approach see the StitchIt
% manual. This function is a wrapper for the code described here:
% https://github.com/mkazhdan/DMG For this MATLAB function to
% run you must download (and compile if necessary) the binaries from the
% the GIST project web page. These need to be added to your system path.
% You then call this function from the experiment root directory.
%
% Although the binaries may be compiled for all platforms, this batch
% script will only run in the background (non-blocking) on Mac and Linux.
%
% INPUTS
% section -  1) a scalar (the z section in the brain) or vector that is: 
%               [physicalSection,opticalSection]. Stitches one plane only.
%            2) a vector of length two [physical section, optical section]. Stitches one plane only
%            3) matrix defining the first and last planes to stitch:
%               [physSec1,optSec1; physSecN,optSecN]
%            4) if empty, attempt to stitch from all available data directories
%
% chan - which channel to process [default 2]
% saveFname - the name of the output tiff. [default 'OUT.tif']
% ind - [scalar] if we're running in parallel then this scalar is used to set the port of the server. 
%       optional. zero by default. the default port is 12340. if ind=23 then the port will be
%       123423 if ind=999 then the port will be 1234999 etc... 
% runInBackGround - zero by default. If zero then function blocks until the result image is 
%                   is written and the temporary images are deleted. If 1, the binary is run
%                   in the background and the user can use the third output argument to delete
%                   the temporary files. No temp files deleted by this function and the function
%                   ceases to block once it has created the temporary files and started the analysis. 
%                   Running in the background is not available on Windows. 
%
%
% OUTPUTS
% im - the image to correct
% mask - the mask for the correction
% tempFileNames - cell array of temp files that were used
%
% Note: you must have the full sized (100% images to work with) because 
%       the function currently doesn't support the reduced resolution stacks.
%
% Rob Campbell - Basel 2015
%
% See also:
% applyGIST2section_BATCH

%number of threads per image. Changing this doesn't result in big speed differences beyond a certain 
%point and in particular not when we're running many sections simulataneously with applyGIST2section_BATCH
nThreads=4;

section=handleSectionArg(section);
if length(section) ~= 2
    fprintf('%s requires a single section to be defined. Quitting.\n',mfilename)
    return
end

if nargin<2 || isempty(chan)
    chan=2;
end

if nargin<3 || isempty(saveFname)
    saveFname='OUT.tif';
end

if nargin<4 || isempty(ind)
    ind=0;
end

if nargin<5 || isempty(ind)
    runInBackGround=0;
end

if ispc && runInBackGround
    fprintf('Running in the background is not supported on Windows. Reverting to non-background mode\n')
    runInBackGround=1;
end


% We have to work with the full resolution images as currently these are the only ones
% that have a the tile coordinates. 
resize=100; 


%Find the path for the full-res (for now) stitched section
stitchedDir = sprintf('stitchedImages_%03d%s%d',resize,filesep,chan);
if ~exist(stitchedDir,'dir')
    fprintf('Stitched directory %s does not exist\n',stitchedDir)
    return
end

stitchedFname = sprintf('%s%ssection_%03d_%02d.tif',stitchedDir,filesep,section);
if ~exist(stitchedFname,'file')
    fprintf('Stitched section %s does not exist\n',stitchedFname)
    varargout{1}=0;
    return
end



fprintf('Building mask\n')
detailsFname = sprintf('%s%sdetails%stilePos_%03d_%02d.csv',stitchedDir,filesep,filesep,section);
mask=tileCoords2MaskIm(detailsFname);
if isempty(mask)
    return %error already issued by tileCoords2MaskIm
end


%Now we save the mask
tempDir=[pwd,filesep];

%maskFname=sprintf('%smask_%03d_%02d.tif',maskDir,section);
maskFname=[tempDir,saveFname,'mask.tif'];


fprintf('Loading section\n')
im=imread(stitchedFname);


%Raise a warning if the mask and image are different sizes
if any(size(mask)-size(im))
    fprintf('WARNING! image (%dx%d) and mask (%dx%d) are different sizes\n',size(im),size(mask))
    return
end

fprintf('Saving mask (%dx%d)\n',size(mask))
imwrite(mask,maskFname,'compression','none');


thresh=0.8E4;
im(im>thresh)=thresh;


localSection=sprintf('%s%sSECTION.tif',tempDir,saveFname);
fprintf('Saving section (%dx%d) to %s\n',size(im),localSection)
imwrite(im,localSection)


%set up the GIST server and run command
iWeight=0.0001 / (resize/100); %the size of the filter depends on how much we have resized the image

%--quality 0 will make uncompressed TIFFs
serverCommand = sprintf('Server --count 1 --port 1234%d --quality 0 --gray --iWeight %f & ',ind,iWeight);


clientCommand=sprintf('Client --pixels %s --labels %s --lowPixels %s --address 127.0.1.1 --port 1234%d --threads %d --hdr --inCore --temp %s --out %s',...
    localSection,maskFname,localSection,ind,nThreads,tempDir,saveFname);

if runInBackGround
    clientCommand = [clientCommand,' &'];
end


%Run the analysis
fprintf('\nRunning: %s\n',serverCommand)
unix(['LD_LIBRARY_PATH= ', serverCommand]); %defining LD_LIBRARY_PATH as blank is needed to avoid the MATLAB version of GLIBC being used


fprintf('\nRunning: %s\n',clientCommand)
unix(['LD_LIBRARY_PATH= ',clientCommand]); %defining LD_LIBRARY_PATH as blank is needed to avoid the MATLAB version of GLIBC being used


%Tidy up
if ~runInBackGround
    %tidy up
    delete(localSection)
    delete(maskFname)
end



if nargout>0
    varargout{1}=im;
end

if nargout>1
    varargout{2}=mask;
end

if nargout>2
    varargout{3}={localSection,maskFname};
end