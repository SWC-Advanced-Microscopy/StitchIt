function section=handleSectionArg(section)
% Handle section arg for various functions such as stitchSection
%
% function section=handleSectionArg(section) 
%
% Purpose
% Physical section/optical section converter.
%
% INPUTS
% section -  1) A scalar (the z section in the brain). Used to retrieve one plane only.
%            2) A vector of length two [physical section, optical section]. 
%            3) 2 by 2 matrix defining the first and last planes to stitch:
%               [physSec1,optSec1; physSecN,optSecN]
%            4) If empty, all available sections are returned as an N by 2 matrix. 
%               In this mode is looks at the number of section directories and 
%               bases the output on this. Not on the meta-data file (recipe or mosaic file)
%
%
% OUTPUTS
% section - an n by 2 matrix. First column is physical section number 
%           and second column is optical section number.
%
%
% Examples
% 
% A)
% In a sample with 2 optical sections per physical section, the optical layer 100
% corresponds to physical section 50, layer 2:  
% >> handleSectionArg(100)      
%
% ans =
%
%    50     2
%
% B) 
% Get all sections between the first and layer 2 of physical section 3:
% >> handleSectionArg([1,1;3,2])  
%
% ans =
%
%     1     1
%     1     2
%     2     1
%     2     2
%     3     1
%     3     2
%
%
% Rob Campbell
%
% See also:
% zPlane2section


mosaicFile=getTiledAcquisitionParamFile;
param=readMetaData2Stitchit(mosaicFile);
config=readStitchItINI;

if isempty(section)

    baseName=directoryBaseName(mosaicFile);
    sectionDirectories=dir([config.subdir.rawDataDir,filesep,baseName,'*']); 

    for ii=1:length(sectionDirectories)
        sectionNumber(ii)=sectionDirName2sectionNum(sectionDirectories(ii).name);
    end

    if isempty(sectionDirectories)
        sectionNumber=1:param.mosaic.numSections;
        fprintf('No section dirs: guessing there are %d sections based on Mosaic file\n',param.mosaic.numSections)
    end
    section=stitchit.tools.setprod(sectionNumber,1:param.mosaic.numOpticalPlanes);
elseif isscalar(section)
    section=zPlane2section(section);
elseif ~isvector(section)
    section=section2zPlane(section(1,:)) : section2zPlane(section(2,:));
    section=zPlane2section(section);
end


%TODO: Remove physical sections lacking an index file
