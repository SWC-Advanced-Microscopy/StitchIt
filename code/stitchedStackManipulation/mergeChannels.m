function mergeChannels(channels, operation, varargin)
% Combine two channels to create a new one by adding them, subtracting then, dividing one from the other, etc.
%
% function mergeChannels(channels, operation, 'Param1', Val1, ...)
%
%
% Purpose
% Provides simple operations to facilitate tasks such as channel unmixing. 
% Conducts "operation" on "channels" according to the following parameters. 
%
%
% INPUTS (required)
% channels  - vector or cell array of channels to process. e.g. if [1,2] or {'1','2'}
%             or even {'1',2} then we process channels 1 and 2. In the event that one 
%             of the defined channels is a "new" merged channel, this argument could 
%             even be something like: {1,'2plus3'}
% operation - A string defining which operation to perform on the channels:
%           'add' - adds two or more channels plus an offset OUT = Ch1 + Ch2 + ChN + offset;
%           'sub' - subtract two or more channels plus an offset OUT = Ch1 - Ch2 - ChN + offset;
%           'div' - fits chan(2) as a function of chan(1) and returns the residuals
%           'ave' - averages n channels and adds an optional offset
%
% INPUTS (optional)
% stitchedDir - [string, "stitchedImages_100" by default]. This is the relative path to the stitched data.
% destDir   - Relative path of folder where data will be written. By default destDir = stitchedDir
% offset    - [scalar, 0 by default]. Adds offset (can be negative) to the returned channel (not valid for all merge types).
% overwrite - [bool false by default]. If true, overwrites data in destDir. 
% sectionRange  - the range of sections to be processed, optional, by defalt empty. Otherwise:
%             1) a vector of length two [physical section, optical section]. Handles this plane only.
%             2) matrix defining the first and last planes: [physSec1,optSec1; physSecN,optSecN]. 
%             3) if empty, attempt to process all available data directories. (default)
%
%
% EXAMPLES
% One - divide channel 1 by channel 2
% >> mergeChannels([1,2],'div')    
%   This makes a new channel called 'MERGE_div_1_2/' under the default stitched directory (stitchedImaged_100)
%   It performs the operions: OUT = Ch1 - Ch2 * slope;
%   Where "slope" is the slope of a linear regression of each optical section:
%   Ch1 = Ch1*slope + intercept
%
%
% Two - divide channel 2 by channel 1 
% >> mergeChannels([2,1],'div')  
%
% Three - add chans 2 and 3 then divide by 1
% >> mergeChannels([2,3],'add')
% >> mergeChannels({'MERGE_add_2_3',1},'div')
%
% Four - add chans 1, 2, and 3
% >> mergeChannels([1,2,3],'add')
%
% Five - look for images in a non-standard directory
% >> mergeChannels([1,2],'div','stitchedDir','stitchedImages_100_GIST')
%
%
%
% Yunyun Han - Basel, 2016-01-31
% Rob Campbell - Basel, 2017-02-28


% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% Handle input arguments
if nargin<2
    fprintf('At least two input arguments are needed\n')
    return
end

if length(channels)<2
    fprintf('Argument "channels" should have a length of at least 2\n')
    return
end

if ~ischar(operation)
    fprintf('Argument "operation" should be a string\n')
    return
end




% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
% Parse optional arguments
params = inputParser;

params.CaseSensitive=false;
params.addParameter('stitchedDir', 'stitchedImages_100', @ischar);
params.addParameter('destDir', '', @ischar);
params.addParameter('overwrite', false, @(x) islogical(x) | x==1 | x==0);
params.addParameter('offset', 0, @isnumeric);
params.addParameter('sectionRange', [], @isnumeric);

params.parse(varargin{:});

stitchedDir = params.Results.stitchedDir;
destDir = params.Results.destDir;
if isempty(destDir)
    destDir=stitchedDir;
end
overwrite = params.Results.overwrite;
offset = params.Results.offset;
sectionRange = params.Results.sectionRange;


%Does the stitched image directory exist?
if ~exist(stitchedDir,'dir')
    fprintf('Can not find directory %s\n', stitchedDir)
    return
end

validOperations={'add','sub','div','ave'};
operation = lower(operation);
if isempty(strmatch(operation,validOperations))
    fprintf('operation %s is not a valid operation. Valid operations are:\n',operation)
    cellfun(@(x) fprintf('* %s\n',x), validOperations)
    fprintf('QUITTING\n')
    return
end


%The division handles just two images
if size(sectionRange,1)<=2 
    section=handleSectionArg(sectionRange);
else
    fprintf('sectionRange should be >2\n')
    return
end


%Generate image file names
for ii=1:size(section,1)
    sectionNames{ii}=sprintf('section_%03d_%02d.tif',section(ii,1),section(ii,2));
end



%Build directory paths and find image files
if ~iscell(channels)
    channels = num2cell(channels); %convert to a cell array
end

%Make sure all elements in the cell array are strings
channels = cellfun(@num2str,channels,'UniformOutput',false); 


%Ensure we have the correct number of channels for the operation being peformed
if length(channels)<2
    fprintf('Argument "channels" should have a length of at least 2. QUITTING\n')
    return
end
switch operation
    case 'div'
        if length(channels) ~= 2
            fprintf('Channel division works with only two channels. QUITTING\n')
            return
        end
end


chanOutputDir = ['MERGE_',operation]; %Used to build the directory name into which we will place the data

for ii=1:length(channels)
    thisChan = channels{ii};
    % Builds the directory names that contain the channel data. 
    % e.g. stitchedImages_100/1 or  stitchedImages_100/1div2
    stitchedDirs{ii} = fullfile(stitchedDir, thisChan);

    %Check channel directory is present
    if ~exist(stitchedDirs{ii},'dir')
        fprintf('Folder %s not found. QUITTING\n', stitchedDirs{ii})
        return
    end

    %Get list of TIFFs in the directory
    tifs{ii} = dir(fullfile(stitchedDirs{ii}, '*.tif'));
    if isempty(tifs) 
        fprintf('No tiffs found in directory %s. QUITTING\n',stitchedDirs{ii});
        return
    end

    chanOutputDir = [chanOutputDir, '_', thisChan]; %Build up dir name
end


if isempty(sectionRange) %The user asked for all sections
    %check that the are same length
    lenTiffs = cellfun(@length,tifs);
    if all(diff(lenTiffs)==0)
        fprintf('Found %d images\n',length(tifs{1}))
    else
        fprintf('The number of TIFFs is not equal across channels. Suggest you define a channel range to work with. QUITTING\n')
        return
    end

    %Get the image file names for one channel (they will be the same for all)
    for ii=1:length(tifs{1})
       imName{ii}= tifs{1}(ii).name;
    end

else %The user asked for a range of sections

    if size(sectionRange,1)<=2 
        section=handleSectionArg(sectionRange);
    else
        fprintf('Inout argument "sectionRange" should be empty or have a length >2. QUITTING\n')
        return
    end

    for ii=1:size(section,1)
        imName{ii}=sprintf('section_%03d_%02d.tif',section(ii,1),section(ii,2));
    end

end



% We now make a directory into which we will place the merged images. The directory
% will be named according to the operation being performed and the channels it is
% being performed on. 
targetDir=fullfile(destDir,chanOutputDir); 
if ~exist(targetDir,'dir')
    success=mkdir(targetDir);
    if ~success
        fprintf('Failed to make directory %s. Quitting\n',targetDir)
        return
    end
end


%Loop through the sections, load in each turn and perform the requested operation on each in turn

parfor ii=1:length(imName)
    theseImages={};
    mu=[];
    if exist(fullfile(targetDir,imName{ii}), 'file') &&  ~overwrite %Skip if file is present and we're not over-writing
        fprintf('File %s exists. SKIPPING\n', fullfile(targetDir,imName{ii}))
        continue
    end

    %Load the stitched images
    for kk=1:length(stitchedDirs)
        theseImages{kk} = stitchit.tools.openTiff(fullfile(stitchedDirs{kk},imName{ii}));        
    end


    switch operation
        case 'add'
            mu = ones(size(theseImages{1}), class(theseImages{1})) * offset; 
            for kk=1:length(theseImages)
                mu = mu + theseImages{kk};
            end
        case 'sub'
            mu = ones(size(theseImages{1}), class(theseImages{1})) * offset; 
            for kk=1:length(theseImages)
                mu = mu - theseImages{kk};
            end
        case 'ave'
            mu = zeros(size(theseImages{1}), class(theseImages{1}));
            for kk=1:length(theseImages)
                mu = mu + theseImages{kk};
            end
            mu = (mu/length(theseImages)) + ones(size(mu), class(theseImages{1})) * offset; 
        case 'div'
            imA = single(theseImages{1});
            imB = single(theseImages{2});
            fitresult=polyfit(imB,imA,1);
            mu=imA-imB*fitresult(1);
    end

    % write the result image
    imwrite(uint16(mu), fullfile(targetDir,imName{ii}), 'Compression', 'None');
    fprintf('%s processed\n', imName{ii})

end 


%Make a file that says when this was done
fid = fopen(fullfile(targetDir,'merge_channels_info.txt'),'w');
fprintf(fid,'Made by %s on %s\n', mfilename,  datestr(now,'yyyy-mm-dd'));
fclose(fid);
