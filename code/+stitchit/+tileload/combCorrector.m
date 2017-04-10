
function im = combCorrector(im,sectionDir,coords,userConfig)
    % crops tiles for stitchit tileLoad
    %
    % function im = stitchit.tileload.combCorrector(im,sectionDir,coords,userConfig)
    %
    % Purpose
    % There are multiple tileLoad functions for different imaging systems
    % but all do the comb correction of tiles the same way using this function. 
    % This function is called by tileLoad.
    %
    % Inputs
    % im - the image stack to crop
    % sectionDir - Path to the directory containing section data. 
    % coords - the coords argument from tileLoad
    % userConfig - [optional] this INI file details. If missing, this 
    %              is loaded and cropping params extracted from it. 
    %
    % Outputs
    % im - the cropped stack. 
    %
    %
    % Rob Campbell - Basel 2017

    if nargin<4 || isempty(userConfig)
        userConfig = readStitchItINI;
    end

    % DUPE
    %TODO: this is duplicated from tileLoad. 
    % it's easier this way but if it takes too long, we can feed in these
    % variables from tileLoad
    % 
    %Load tile index file (this function isn't called if the file doesn't exist so no 
    %need to check if it's there.
    tileIndexFile=sprintf('%s%stileIndex',sectionDir,filesep);
    index=readTileIndex(tileIndexFile);


    %Find the index of the optical section and tile(s)
    f=find(index(:,3)==coords(2)); %Get this optical section 
    index = index(f,:);

    indsToKeep=1:length(index);

    if coords(3)>0
        f=find(index(:,4)==coords(3)); %Row in tile array
        index = index(f,:);
        indsToKeep=indsToKeep(f);
    end

    if coords(4)>0
        f=find(index(:,5)==coords(4)); %Column in tile array
        index = index(f,:);
        indsToKeep=indsToKeep(f);
    end
    %% /DUPE

    corrStatsFname = sprintf('%s%sphaseStats_%02d.mat',sectionDir,filesep,coords(2));

    if ~exist(corrStatsFname,'file')
        fprintf('%s. phase stats file %s missing. \n',mfilename,corrStatsFname)
    else
        load(corrStatsFname);
        phaseShifts = phaseShifts(indsToKeep);
        im = applyPhaseDelayShifts(im,phaseShifts);
    end


