
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

    % DOES NOTHING YET


    if nargin<4 || isempty(userConfig)
        userConfig = readStitchItINI;
    end

    return

    %corrStatsFname = sprintf('%s%sphaseStats_%02d.mat',sectionDir,filesep,coords(2));

    %if ~exist(corrStatsFname,'file')
    %    fprintf('%s. phase stats file %s missing. \n',mfilename,corrStatsFname)
    %else
    %    load(corrStatsFname);
    %    phaseShifts = phaseShifts(indsToKeep);
    %    im = applyPhaseDelayShifts(im,phaseShifts);
    %end
