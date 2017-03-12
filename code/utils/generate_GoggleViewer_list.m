function varargout=generate_GoggleViewer_list(stitchedDir,overide)
% Make GoggleViewer files listing the stitched file locations
%
% function status=generate_GoggleViewer_list(stitchedDir,overide)
%
%
% Purpose
% Make stitched image file lists from data stitched with tvMat to
% enable import into GoggleViewer.
%
%
% Inputs
% stitchedDir - path to stitched data directory. e.g. 'stitchedImages_100'
% overide - [optional, 0 by default] if 1, build channel lists even if sections are missing
% 
% 
% Outputs
% status - [optional]
%           -1 - failed to build anything
%            0 - made partial list but there are missing sections
%            1 - made complete list
%
%
% Examples
% generate_GoggleViewer_list('stitchedImages_100')
% 
% Rob Campbell
%
% Notes: 
% Produces file with unix file seps on all platforms. Windows
% MATLAB seems OK about using these paths. Windows fileseps 
% mess up the fprintf.

if nargin<2
    overide=0;
end


if ispc
    fprintf('Fails on Windows machines. Not fixed yet\n')
end

if ~exist(stitchedDir,'dir')
    fprintf('Directory %s not found\n',stitchedDir)
    return
end


%Make file root name
params=readMetaData2Stitchit;
stitchedFileListName=[params.sample.ID,'_StitchedImagesPaths_'];


%find the channels
chans = dir(stitchedDir);

for ii=1:length(chans)

    if regexp(chans(ii).name,'\d+')


        tifDir=[stitchedDir,'/',chans(ii).name];
        tifs=dir([tifDir,'/','*.tif']);

        if isempty(tifs)
            fprintf('No tiffs in %s. Skipping\n',tifDir)
            continue
        end

        missing=findMissingSections(tifs);
        if missing & ~overide
            fprintf('\nMissing sections. Not building the image lists.\nPlease fix your data or overide this warning (help %s), if you know what you''re doing. \n\n',mfilename)
            if nargout>0
                varargout{1}=-1;
            end
            return
        end
        if missing & overide
            fprintf('\n BUILDING THE LISTS WITH MISSING SECTIONS\n\n')

        end
    

        fprintf('Making channel %s file\n',chans(ii).name)
        thisChan = str2num(chans(ii).name);
        
        fid=fopen(sprintf('%sCh%02d.txt',stitchedFileListName,thisChan),'w+');
        for thisTif = 1:length(tifs)         
                fprintf(fid,[tifDir,'/',tifs(thisTif).name,'\n']);
            
        end
        fclose(fid);

    end

end


if nargout>0
    varargout{1}=~missing;
end

function missing=findMissingSections(tifs)
    %Look for missing sections 
    sections = zeros(length(tifs),1);
    optical = zeros(length(tifs),1);    


    for ii=1:length(tifs);
        tok=regexp(tifs(ii).name,'section_(\d+)_(\d+)','tokens');
        if isempty(tok)
            error('regexp failed')
        end

        tok=tok{1};
        if length(tok)~=2
            error('Failed to find two tokens')
        end

        sections(ii) = str2num(tok{1});
        optical(ii) = str2num(tok{2});              
    end

    sections=unique(sections);
    optical=unique(optical);

    missing=0;
    %now check if any sections arem missing (a bit brute-force, but it'll work)
    for sct=1:length(sections)
        for opt=1:length(optical)

            f=find(sections==sct);
            if isempty(f)
                fprintf('\t ** Missing physical section %d, optical section %d **\n',sct,opt)
                missing=1;
            end

        end
    end


