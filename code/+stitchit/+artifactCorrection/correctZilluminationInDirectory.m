function varargout=correctZilluminationInDirectory(sectionDirectory,outputDirectory,verbose)
% Correct illumination of different optical sections in a physical section
%
% function stats=correctZilluminationInDirectory(sectionDirectory,outputDirectory,verbose)
%
% Purpose
% Imaging deeper in a physical section results in more scatter and dimmer images. We
% can correct for this with higher laser power, but it is hard to do this precisely. 
% This function therefore corrects for small differences in intensity between optical 
% sections. 
%
%
% Inputs
% sectionDirectory - the directory containing the optical sections. One file
%   per optical section. File names are in the format \W+_Z\d{3}_L\d{3}.tiff
%   e.g. StitchedImage_060_004.tif Where the first number tells you the physical
%   section and the second the optical section. 
%
% outputDirectory - [OPTIONAL] If present, save results to this directory. If
%   absent, overwrite original files. If empty we also overwrite original data.
%
% verbose - [OPTIONAL] 0 by default. If 1, we report progress to screen and make a 
%           graph at the end showing the correction performance. 
%
%
% Outputs
% stats - the before and after mean intensity for each section. 
%
%
% Example
% Correct channel 1 and overwrite data:
% correctZilluminationInDirectory('stitchedImages_100/1')
%
%  Rob Campbell - Basel 2014



% Handle input arguments
if ~exist(sectionDirectory,'dir')
    error('Section directory %s not present',sectionDirectory);
end

%Add seperator to the end if needed
if isempty(regexp(sectionDirectory(end),'[\\/]'))
    sectionDirectory(end+1)=filesep;
end

if nargin<3
    verbose=0;
end

if nargin<2 | isempty(outputDirectory)
    outputDirectory=sectionDirectory;
else
    if isempty(regexp(outputDirectory(end),'[\\/]')) 
        outputDirectory(end+1)=filesep;
    end

end

if verbose & strcmp(outputDirectory,sectionDirectory)
    fprintf('%s: replacing sections in %s with illumination corrected versions\n',...
        mfilename, sectionDirectory)
end





%Figure out how many optical and physical sections we have
sections=dir([sectionDirectory,'*.tif']);
if length(sections)==0
    error('Can not find any tif files in %s\n',sectionDirectory)
end


%Figure out the number of optical sections per physical section
sectionId=ones(length(sections),3); %[physical section index, optical section index]
for ii=1:length(sectionId)
    tok=regexp(sections(ii).name,'\D+_(\d+)_(\d+).*tif','tokens');
    tok=tok{1};

    sectionId(ii,1)=ii;
    sectionId(ii,2)=str2num(tok{1});
    sectionId(ii,3)=str2num(tok{2});
end

uPhys=unique(sectionId(:,2));
nPhys=length(uPhys); %number of physical sections

uOpt=unique(sectionId(:,3));
nOpt=length(uOpt);  %number of optical sections per physical section

if verbose
    fprintf('Found %d physical sections with %d optical sections each\n',nPhys,nOpt)
end



%Create data directory if needed
if ~exist(outputDirectory)
    mkdir(outputDirectory)
    if verbose
        fprintf('Making %s\n', outputDirectory)
    end
end

%If verbose, we make a plot of brain intensity profile before and after correction
if verbose
    profileBefore = ones(nOpt,nPhys);
    profileAfter = ones(nOpt,nPhys);
end


%This function can end up load a LOT of data. So let's make sure we don't hit the limit
%of what the machine will tolerate
im=imfinfo([sectionDirectory,sections(1).name]);

G=gcp;
maxWorkers = G.NumWorkers;

if strcmp(im.Compression,'Uncompressed') 
    fSize=im.FileSize/1024^3; %Gigs per image
    params=readMetaData2Stitchit(getTiledAcquisitionParamFile);
    RAMperSection = params.mosaic.numOpticalPlanes * fSize * 3.1; %Rough empirical estimate of RAM requried 
    freeGigs = freemem * 0.85; %Because we don't want to use it all
    nWorkers=floor(freeGigs/RAMperSection);
    if nWorkers>maxWorkers
        nWorkers=maxWorkers;
    end
    fprintf('Using %d workers with estimated RAM usage of %1.1f GB per thread.\n',nWorkers,RAMperSection)
else
    nWorkers=maxWorkers;
    fprintf('Files are compressed. Just using %d cores. May run out of RAM.\n',nWorkers)
end

%Loop through each physical section. We load the images corresponding to it, apply 
%the correction, save the data, the on to the next physical section. 
parfor (ii=1:nPhys,nWorkers)
    f=find(sectionId(:,2)==uPhys(ii));
    
    thisSectionId=sectionId(f,:);
    %Issue a warning if the number of optical sections don't match what we
    %expect
    if size(thisSectionId,1)~=nOpt
        fprintf('%s: at Z=%d expected %d optical sections but found %d\n',...
            mfilename, uPhys(ii), nOpt, size(thisSectionId,1))
    end


    %Load all optical sections for this physical section
    thisSection=stitchit.tools.openTiff([sectionDirectory,sections(thisSectionId(1,1)).name]);
    thisSection=repmat(thisSection,[1,1,size(thisSectionId,1)]);
    for jj=2:size(thisSectionId,1)
        thisSection(:,:,jj)=stitchit.tools.openTiff([sectionDirectory,sections(thisSectionId(jj,1)).name]);
    end
    if verbose
        fprintf('\n')
    end

    if verbose
        fprintf('%0.3d/%0.3d.\n',ii,nPhys)
        muBefore=round(squeeze(mean(mean(thisSection))));
        %medBefore=round(squeeze(median(median(thisSection))));
        profileBefore(:,ii)=muBefore;
    end



    %Correct the data
    thisSection=smoothingRescale(thisSection,verbose);


    if verbose
        muAfter=round(squeeze(mean(mean(thisSection))));
        %medAfter=round(squeeze(median(median(thisSection))));
        profileAfter(:,ii)=muAfter;
    end


    %Save the data
    for jj=1:size(thisSectionId,1)
        imwrite(thisSection(:,:,jj),...
            [outputDirectory,sections(thisSectionId(jj,1)).name],'tif','Compression','none')
    end


end

if verbose
    fprintf('\n')
end

if ~verbose
    return
end

clf
plot(profileBefore(:),'-r')
hold on
plot(profileAfter(:),'-k','linewidth',2)
hold off
xlim([1,length(profileAfter(:))])
xlabel('Section')
ylabel('Mean intensity')
if nargout>0
    out.before=profileBefore;
    out.after=profileAfter;
    varargout{1}=out;
end




% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
%Internal functions follow


function thisSection=smoothingRescale(thisSection,verbose)
% Algorithm:
% 0. Remove the top 0.01% of pixels by setting a ceiling. (optional)
% 1. Smooth each section with a big fat Gaussian
% 2. Figure out the ratio at each pixel between the top section and the lower ones
% 3. Divide all sections beneath the surface by the number in step 2.


    thisSection=single(thisSection);


    %This failed for the full size images. No time yet to figure out why [raac]
    doReducePixelValues=0; 

    if doReducePixelValues

        if verbose
            fprintf('Removing very high pixel values')
        end

        %Keep reducing the effective bit depth until we have removed the top 0.01% or fewer pixels of pixels. 
        %These are just noisy crap. Doing this should be safe, and keeps the images neater.
        p=0;
        bitDepth=17;
        while p<0.01
            bitDepth=bitDepth-1;
            p=(length(find(thisSection>2^bitDepth))/length(thisSection(:)))*100;
            %fprintf('New effective bit depth: %d, prop removed pixels: %0.1f\n',bitDepth,p)
        end

        bitDepth=bitDepth+1;
        thisSection(thisSection>2^bitDepth)=2^bitDepth; 

        if verbose
            fprintf('\nReducing pixel values to %d bit\n',bitDepth)
        end
    end %doReducePixelValues [TODO: must fix this for large images - raac]





    %Speed up the processing by reducing the size of the filtered images
    %another option would be to do this in the frequency domain
    maxImSize=1.5E6; %images larger than this number of pixels will be reduced to this size
    thisImSize=prod(size(thisSection(:,:,1)));
    if thisImSize>maxImSize
        resizeBy = thisImSize/maxImSize;

        %So the target image size to achieve 1.5E6 pixels
        targetSize = floor(size(thisSection(:,:,1))/sqrt(resizeBy));
    else
        targetSize = size(thisSection(:,:,1));
        resizeBy=1; 
    end

    %The filter area will be a fixed fraction of the image size
    filterArea = 0.01; %The area of the SD will be this proportion of the image size
    imSize = prod(targetSize);
    SDgaus = round(sqrt(imSize*filterArea/pi)*2);

    G=fspecial('gaussian',SDgaus*3,SDgaus); %great big Gaussian


    %Filter and divide 
    if verbose
        if resizeBy>1
            fprintf('Filtering using %1.1fx downsampled data\n',resizeBy)
        else
            fprintf('Filtering without downsampling data\n')
        end

    end


    %The following line is fairly expensive
    F1=single(imfilter( imresize(thisSection(:,:,1),'OutputSize',targetSize) , G)); %The first layer 

    %Now go through and divide
    for jj=2:size(thisSection,3)
        %The following line is where the bulk of the time is taken
        FthisLayer=single( F1 ./ single(imfilter(imresize(thisSection(:,:,jj),'OutputSize',targetSize),G)) ); 

        %Now correct each section by this factor
        thisSection(:,:,jj)=thisSection(:,:,jj).*imresize(FthisLayer,'OutputSize',size(thisSection(:,:,1)) );
    end


    thisSection=uint16(thisSection);
