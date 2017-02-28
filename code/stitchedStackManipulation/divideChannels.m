function divideChannels(stitchedDir,channels,sectionRange,overwrite,destDir)
% Combine two channels to create a new one. Cheap and easy way to isolate fluorophore signals.
%
% function divideChannels(stitchedDir,channels, offset,sectionRange,overwrite,destDir)
%
%
% Purpose
% Conducts a simple channel unmixing using two channels. 
%
%
% INPUTS 
% stitchedDir - string, path of data folder
% channels  - vector of length 2 of channel index values to process
% sectionRange  - the range of sections to be processed, optional, by defalt empty:
%             1) a vector of length two [physical section, optical section]. Stitches one plane only
%             2) matrix defining the first and last planes to stitch: [physSec1,optSec1; physSecN,optSecN]. 
%             3) if empty, attempt to stitch from all available data directories. default. 
% overwrite - 1, overwrite; 0, not. Optional, default 0.
% destDir   - string, path of target folder, optional, by defaul destDir = stitchedDir
%
%
%
% EXAMPLES
% One - 
% make a new channel called '7' under the default stitched directory
%       ch7 = ChA - ChB * slope;
%           slope is the slope of linear regression of each optical section:
%            ChA= ChB * slope 
%
% divideChannels('stitchedImages_100',[2,1]);
%     ch7 = ch2 -ch1*slope 
%
%
% Two - 
% divideChannels('stitchedImages_100',[1,2],[140,1;142,2],'./TEST')

%
% Yunyun Han - Basel, 2016-01-31



% Handle input arguments
if ~ischar(stitchedDir)
    fprintf('Argument "stichedDir" should be a string 2 \n')
    return
end

if ~exist(stitchedDir,'dir')
    fprintf('Can not find directory %s\n', stitchedDir)
    return
end

if length(channels)~=2
    fprintf('Argument "channels" should have a length of 2\n')
    return
end

if nargin<3
    sectionRange=[];
end

if nargin<4 || isempty(overwrite)
    overwrite=0;
end

if nargin<5 || isempty(stitchedDir)
    destDir=stitchedDir;
end


%Build directory paths
stitchedDirA = fullfile(stitchedDir, num2str(channels(1)) );
stitchedDirB = fullfile(stitchedDir, num2str(channels(2)) );


%Check channels are present in these directories
if ~exist(stitchedDirA,'dir')
    fprintf('Folder %s not found\n', stitchedDirA)
    return
end

if ~exist(stitchedDirB,'dir')
    fprintf('Folder %s not found\n', stitchedDirB)
    return
end


%List the tiffs in the two channels
tifsA = dir(fullfile(stitchedDirA, '*.tif'));
tifsB = dir(fullfile(stitchedDirB,'*.tif'));


%Check if empty
if isempty(tifsA) || isempty(tifsB)  
    fprintf('No tiffs found in directory %s\n',stitchedDir);
    return
end


if isempty(sectionRange)
    %check that the are same length
    if length(tifsA)==length(tifsB) 
        fprintf('Found %d images\n',length(tifsA))
    else
        fprintf('file number is not equal in channel A, B\n')
        return
    end

    for i=1:length(tifsA)
       name{i}= tifsA(i).name;
    end

else

    if size(sectionRange,1)<=2 
        section=handleSectionArg(sectionRange);
    else
        fprintf('sectionRange should be >2\n')
        return
    end

    for i=1:size(section,1)
        name{i}=sprintf('section_%03d_%02d.tif',section(i,1),section(i,2));
    end

end



%Make a target directory to keep the corrected images
targetDir=fullfile(destDir,'7'); %TODO: hard-coded **problem**
if ~exist(targetDir,'dir')
    success=mkdir(targetDir);
    if ~success
        fprintf('Failed to make directory %s. Quitting\n')
        return
    end
end



%Loop through the sections
parfor ii=1:length(name)
    
    if exist(fullfile(targetDir,name{ii}), 'file') &&  ~overwrite
        fprintf('File %s exists. SKIPPING\n', fullfile(targetDir,name{ii}))
    else
        %The two stitched sections
        imA = stitchit.tools.openTiff(fullfile(stitchedDirA,name{ii}));
        imB = stitchit.tools.openTiff(fullfile(stitchedDirB,name{ii}));

        imA = single(imA);
        imB = single(imB);

        fitresult=polyfit(imB,imA,1);
        mu=uint16(imA-imB*fitresult(1)); %Save the residuals. The first coefficient in "fitresult" is the slope, not the intercept 

        % write the result image
        imwrite(mu, fullfile(targetDir,name{ii}), 'Compression', 'None');
        fprintf('%s processed\n', name{ii})
    end
end 


%Make a file that says what the average was
fid = fopen(fullfile(targetDir,'divide_Channels_Info.txt'),'w');
fprintf(fid,'Made by %s on %s\n', mfilename,  datestr(now,'yyyy-mm-dd'))
fprintf(fid,'Ch07 = Ch%02d - Ch%02d * slope) /n Ch%02d= Ch%02d * slope ', ...
    channels(1),channels(2), channels(1),channels(2));
fclose(fid);
